using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.ConnectionAnalytics;

public sealed class SQLiteConnectionAnalyticsLedger : IConnectionAnalyticsLedger
{
    private readonly string _databasePath;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private ConnectionAnalyticsLedgerPersistence? _persistence;
    private string? _lastPrunedLocalDay;

    public SQLiteConnectionAnalyticsLedger(string databasePath)
    {
        _databasePath = databasePath;
    }

    public Task<ConnectionAnalyticsLedgerSnapshot> PrepareAsync(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            var persistence = RequirePersistence();
            PruneIfNeeded(timeZone, now, persistence);
            return Snapshot(timeZone, now, persistence);
        }, cancellationToken);
    }

    public Task<ConnectionAnalyticsLedgerSnapshot> SetHistoryEnabledAsync(
        bool isEnabled,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            var persistence = RequirePersistence();
            persistence.SetHistoryEnabled(isEnabled);
            return Snapshot(timeZone, now, persistence);
        }, cancellationToken);
    }

    public Task<ConnectionAnalyticsLedgerSnapshot> RecordAsync(
        IReadOnlyList<ConnectionAttributionAggregate> aggregates,
        int maximumPairCountPerDay,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        if (maximumPairCountPerDay <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(maximumPairCountPerDay));
        }

        return ExecuteAsync(() =>
        {
            var persistence = RequirePersistence();
            if (!persistence.IsHistoryEnabled())
            {
                return Snapshot(timeZone, now, persistence);
            }

            persistence.Transaction(transaction =>
            {
                foreach (var group in Coalesced(aggregates)
                    .GroupBy(aggregate => aggregate.Key.LocalDay))
                {
                    RecordDay(
                        group.ToArray(),
                        maximumPairCountPerDay,
                        persistence,
                        transaction);
                }
                PruneIfNeeded(timeZone, now, persistence, transaction);
            });
            return Snapshot(timeZone, now, persistence);
        }, cancellationToken);
    }

    public Task<IReadOnlyList<ConnectionAttributionRecord>> RecordsAsync(
        string localDay,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync<IReadOnlyList<ConnectionAttributionRecord>>(
            () => RequirePersistence().Records(localDay),
            cancellationToken);
    }

    public Task<ConnectionAnalyticsTrend> TrendAsync(
        ConnectionAnalyticsTrendQuery query,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            var days = ConnectionAnalyticsCalendar.RecentLocalDays(now, timeZone);
            var stored = RequirePersistence().Trend(query, days[0]);
            var storedByDay = stored.ToDictionary(
                point => point.LocalDay,
                StringComparer.Ordinal);
            return new ConnectionAnalyticsTrend(days
                .Select(day => storedByDay.GetValueOrDefault(
                    day,
                    new ConnectionAnalyticsTrendPoint(day, TrafficBytes.Zero)))
                .ToArray());
        }, cancellationToken);
    }

    public Task<ConnectionAnalyticsLedgerSnapshot> ClearHistoryAsync(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            var persistence = RequirePersistence();
            persistence.Transaction(persistence.ClearHistory);
            return Snapshot(timeZone, now, persistence);
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

    private async Task<T> ExecuteAsync<T>(
        Func<T> operation,
        CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            cancellationToken.ThrowIfCancellationRequested();
            return operation();
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (ConnectionAnalyticsException)
        {
            throw;
        }
        catch (Exception exception) when (
            exception is SqliteException
                or IOException
                or UnauthorizedAccessException
                or OverflowException
                or InvalidCastException
                or FormatException)
        {
            throw new ConnectionAnalyticsException(
                "连接归因数据库暂不可用，实时连接不受影响。",
                exception);
        }
        finally
        {
            _gate.Release();
        }
    }

    private ConnectionAnalyticsLedgerPersistence RequirePersistence()
    {
        return _persistence ??= new ConnectionAnalyticsLedgerPersistence(_databasePath);
    }

    private static IReadOnlyList<ConnectionAttributionAggregate> Coalesced(
        IReadOnlyList<ConnectionAttributionAggregate> aggregates)
    {
        var bytesByKey = new Dictionary<ConnectionAttributionStorageKey, TrafficBytes>();
        foreach (var aggregate in aggregates)
        {
            bytesByKey[aggregate.Key] = TrafficBytes.Add(
                bytesByKey.GetValueOrDefault(aggregate.Key, TrafficBytes.Zero),
                aggregate.Bytes);
        }
        return bytesByKey
            .Select(item => new ConnectionAttributionAggregate(item.Key, item.Value))
            .ToArray();
    }

    private static void RecordDay(
        IReadOnlyList<ConnectionAttributionAggregate> aggregates,
        int maximumPairCount,
        ConnectionAnalyticsLedgerPersistence persistence,
        SqliteTransaction transaction)
    {
        if (aggregates.Count == 0)
        {
            return;
        }

        var localDay = aggregates[0].Key.LocalDay;
        var overflowKey = new ConnectionAttributionStorageKey(
            localDay,
            ConnectionAttributionLabel.Overflow,
            ConnectionAttributionLabel.Overflow);
        var existingKeys = persistence.ExistingKeys(localDay, transaction);
        var regularCount = existingKeys.Count(key => key != overflowKey);
        var remainingRegularSlots = Math.Max(maximumPairCount - 1 - regularCount, 0);
        var overflowBytes = TrafficBytes.Zero;

        foreach (var aggregate in aggregates.OrderBy(
            item => item.Key.ApplicationName,
            StringComparer.Ordinal).ThenBy(
            item => item.Key.Hostname,
            StringComparer.Ordinal))
        {
            if (aggregate.Key == overflowKey || existingKeys.Contains(aggregate.Key))
            {
                persistence.Upsert(aggregate, transaction);
            }
            else if (remainingRegularSlots > 0)
            {
                persistence.Upsert(aggregate, transaction);
                remainingRegularSlots -= 1;
            }
            else
            {
                overflowBytes = TrafficBytes.Add(overflowBytes, aggregate.Bytes);
            }
        }

        if (overflowBytes != TrafficBytes.Zero)
        {
            persistence.Upsert(
                new ConnectionAttributionAggregate(overflowKey, overflowBytes),
                transaction);
        }
    }

    private void PruneIfNeeded(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        ConnectionAnalyticsLedgerPersistence persistence,
        SqliteTransaction? transaction = null)
    {
        var localDay = ConnectionAnalyticsCalendar.LocalDay(now, timeZone);
        if (string.Equals(localDay, _lastPrunedLocalDay, StringComparison.Ordinal))
        {
            return;
        }

        var cutoff = ConnectionAnalyticsCalendar.RecentLocalDays(now, timeZone)[0];
        if (transaction is not null)
        {
            persistence.Prune(cutoff, transaction);
        }
        else
        {
            persistence.Transaction(inner => persistence.Prune(cutoff, inner));
        }
        _lastPrunedLocalDay = localDay;
    }

    private static ConnectionAnalyticsLedgerSnapshot Snapshot(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        ConnectionAnalyticsLedgerPersistence persistence)
    {
        var days = ConnectionAnalyticsCalendar.RecentLocalDays(now, timeZone);
        var storedByDay = persistence.DailyTotals(days[0]).ToDictionary(
            day => day.LocalDay,
            StringComparer.Ordinal);
        return new ConnectionAnalyticsLedgerSnapshot(
            persistence.IsHistoryEnabled(),
            days.Select(day => storedByDay.GetValueOrDefault(
                day,
                new ConnectionAnalyticsDay(
                    day,
                    TrafficBytes.Zero,
                    ConnectionAnalyticsCoverage.Empty)))
                .ToArray());
    }
}
