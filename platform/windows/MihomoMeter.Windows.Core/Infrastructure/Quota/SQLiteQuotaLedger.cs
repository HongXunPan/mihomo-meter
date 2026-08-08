using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Quota;

public sealed class SQLiteQuotaLedger : IQuotaLedger
{
    private readonly string _databasePath;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private QuotaLedgerPersistence? _persistence;

    public SQLiteQuotaLedger(string databasePath)
    {
        _databasePath = databasePath;
    }

    public Task<QuotaLedgerSnapshot> PrepareAsync(
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(
            persistence => Snapshot(persistence, now),
            cancellationToken);
    }

    public Task<QuotaLedgerSnapshot> UpsertSubscriptionAsync(
        TrackedSubscription subscription,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(persistence =>
        {
            var existing = persistence.LoadSubscription(subscription.Id);
            if (existing is not null
                && (existing.IdentityMode != subscription.IdentityMode
                    || !string.Equals(
                        existing.ClashProfileUid,
                        subscription.ClashProfileUid,
                        StringComparison.Ordinal)))
            {
                throw new QuotaLedgerException("订阅身份变化需要显式迁移。");
            }

            persistence.Transaction(transaction =>
                persistence.UpsertSubscription(subscription, transaction));
            return Snapshot(persistence, now);
        }, cancellationToken);
    }

    public Task<QuotaLedgerSnapshot> SetSubscriptionStatusAsync(
        Guid subscriptionId,
        SubscriptionTrackingStatus status,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(persistence =>
        {
            persistence.Transaction(transaction => persistence.SetSubscriptionStatus(
                subscriptionId,
                status,
                now,
                transaction));
            return Snapshot(persistence, now);
        }, cancellationToken);
    }

    public Task<QuotaLedgerSnapshot> RecordAsync(
        QuotaObservation observation,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(persistence =>
        {
            var subscription = persistence.LoadSubscription(observation.SubscriptionId)
                ?? throw new QuotaLedgerException("未找到订阅身份。");
            ValidateSource(subscription, observation.Source);
            var previous = persistence.LatestSnapshot(observation.SubscriptionId);
            if (previous is not null && observation.ObservedAt <= previous.ObservedAt)
            {
                throw new QuotaLedgerException("订阅配额观测时间必须递增。");
            }

            var openCycle = persistence.OpenCycle(observation.SubscriptionId);
            persistence.Transaction(transaction =>
            {
                var startsNewCycle = QuotaCycleDetector.RequiresNewCycle(previous, observation);
                Guid cycleId;
                if (startsNewCycle)
                {
                    if (openCycle is not null)
                    {
                        persistence.CloseCycle(
                            openCycle.Id,
                            observation.ObservedAt,
                            transaction);
                    }

                    var cycle = persistence.InsertCycle(
                        observation.SubscriptionId,
                        observation.ObservedAt,
                        previous is null
                            ? QuotaCycleStartReason.Initial
                            : QuotaCycleStartReason.UsageReset,
                        previous is null,
                        transaction);
                    cycleId = cycle.Id;
                }
                else
                {
                    cycleId = previous?.CycleId
                        ?? throw new QuotaLedgerException("订阅周期状态无效。");
                }

                var current = persistence.InsertObservation(observation, cycleId, transaction);
                if (previous is not null)
                {
                    persistence.InsertEvents(
                        previous,
                        current,
                        startsNewCycle,
                        transaction);
                }
            });
            return Snapshot(persistence, now);
        }, cancellationToken);
    }

    public Task<QuotaLedgerSnapshot> SaveQueryStateAsync(
        ProfileQuotaQueryState state,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(persistence =>
        {
            if (persistence.LoadSubscription(state.SubscriptionId) is null)
            {
                throw new QuotaLedgerException("未找到订阅身份。");
            }

            persistence.Transaction(transaction =>
                persistence.UpsertQueryState(state, transaction));
            return Snapshot(persistence, now);
        }, cancellationToken);
    }

    public Task<QuotaLedgerSnapshot> ConfirmCycleAsync(
        Guid cycleId,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(persistence =>
        {
            if (persistence.LoadCycle(cycleId) is null)
            {
                throw new QuotaLedgerException("未找到订阅周期。");
            }

            persistence.Transaction(transaction =>
                persistence.ConfirmCycle(cycleId, transaction));
            return Snapshot(persistence, now);
        }, cancellationToken);
    }

    public Task<QuotaLedgerSnapshot> ResetAsync(
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(persistence =>
        {
            persistence.Transaction(persistence.Reset);
            return QuotaLedgerSnapshot.Empty(now);
        }, cancellationToken);
    }

    public async ValueTask DisposeAsync()
    {
        await _gate.WaitAsync().ConfigureAwait(false);
        try
        {
            _persistence?.Dispose();
            _persistence = null;
        }
        finally
        {
            _gate.Release();
            _gate.Dispose();
        }
    }

    private async Task<QuotaLedgerSnapshot> ExecuteAsync(
        Func<QuotaLedgerPersistence, QuotaLedgerSnapshot> operation,
        CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            cancellationToken.ThrowIfCancellationRequested();
            return operation(RequirePersistence());
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (QuotaLedgerException)
        {
            throw;
        }
        catch (Exception exception) when (
            exception is SqliteException
                or IOException
                or UnauthorizedAccessException
                or OverflowException
                or ArgumentOutOfRangeException
                or InvalidCastException
                or FormatException
                or QuotaDomainException)
        {
            throw new QuotaLedgerException("订阅配额数据库暂不可用。", exception);
        }
        finally
        {
            _gate.Release();
        }
    }

    private QuotaLedgerPersistence RequirePersistence()
    {
        return _persistence ??= new QuotaLedgerPersistence(_databasePath);
    }

    private static QuotaLedgerSnapshot Snapshot(
        QuotaLedgerPersistence persistence,
        DateTimeOffset now)
    {
        var result = new List<SubscriptionQuotaAnalysis>();
        foreach (var subscription in persistence.LoadSubscriptions())
        {
            var latest = persistence.LatestSnapshot(subscription.Id);
            var currentCycle = persistence.OpenCycle(subscription.Id);
            var snapshots = persistence.LoadSnapshots(
                subscription.Id,
                now.AddMonths(-12),
                now);
            var trends = Enum.GetValues<QuotaTrendWindow>().ToDictionary(
                window => window,
                window => QuotaTrendEngine.Calculate(snapshots, window, now));
            result.Add(new SubscriptionQuotaAnalysis(
                subscription,
                latest,
                currentCycle,
                persistence.LoadEvents(subscription.Id, 5),
                persistence.LoadQueryState(subscription.Id),
                trends,
                QuotaTrendEngine.Forecast(
                    snapshots,
                    currentCycle,
                    now,
                    MaximumDataAge(subscription))));
        }

        return new QuotaLedgerSnapshot(result.AsReadOnly(), now);
    }

    private static TimeSpan MaximumDataAge(TrackedSubscription subscription)
    {
        var minimum = TimeSpan.FromHours(24);
        return subscription.RefreshIntervalMinutes is int minutes
            ? TimeSpan.FromMinutes(Math.Max(minimum.TotalMinutes, minutes * 2))
            : minimum;
    }

    private static void ValidateSource(
        TrackedSubscription subscription,
        QuotaObservationSource source)
    {
        var isValid = (subscription.IdentityMode, source) switch
        {
            (SubscriptionIdentityMode.RuntimeSingle, QuotaObservationSource.MihomoRuntime) => true,
            (SubscriptionIdentityMode.ClashProfile, QuotaObservationSource.MeterActiveQuery) => true,
            _ => false,
        };
        if (!isValid)
        {
            throw new QuotaLedgerException("订阅身份与配额来源不匹配。");
        }
    }
}
