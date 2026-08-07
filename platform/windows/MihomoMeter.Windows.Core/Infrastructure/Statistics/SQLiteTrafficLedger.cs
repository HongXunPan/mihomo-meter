using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Statistics;

public sealed class SQLiteTrafficLedger : ITrafficLedger
{
    private readonly string _databasePath;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private TrafficLedgerPersistence? _persistence;
    private TrafficLedgerRuntimeState _runtimeState = new();
    private bool _isPrepared;
    private string? _lastPrunedLocalDay;

    public SQLiteTrafficLedger(string databasePath)
    {
        _databasePath = databasePath;
    }

    public Task<TrafficStatisticsSnapshot> PrepareAsync(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            var persistence = RequirePersistence();
            PrepareIfNeeded(timeZone, now, persistence);
            return Snapshot(timeZone, now, persistence);
        }, cancellationToken);
    }

    public Task<TrafficStatisticsSnapshot> BeginMonitoringAsync(
        string version,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            var persistence = PreparedPersistence(timeZone, now);
            persistence.Transaction(transaction =>
            {
                if (_runtimeState.CurrentSessionId is null)
                {
                    OpenCoreSession(version, now, persistence, transaction);
                }
                else if (!string.Equals(
                    _runtimeState.CurrentMihomoVersion,
                    version,
                    StringComparison.Ordinal))
                {
                    ReplaceCoreSession(
                        version,
                        now,
                        "version_change",
                        persistence,
                        transaction);
                }
            });
            return Snapshot(timeZone, now, persistence);
        }, cancellationToken);
    }

    public Task<TrafficStatisticsSnapshot> RecordAsync(
        TrafficLedgerObservation observation,
        TimeZoneInfo timeZone,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            var persistence = PreparedPersistence(timeZone, observation.ObservedAt);
            persistence.Transaction(transaction =>
            {
                var opensFreshSession = _runtimeState.CurrentSessionId is null;
                if (opensFreshSession)
                {
                    OpenCoreSession(
                        _runtimeState.CurrentMihomoVersion ?? "unknown",
                        observation.ObservedAt,
                        persistence,
                        transaction);
                }

                if (!opensFreshSession)
                {
                    switch (observation.Transition)
                    {
                        case TrafficLedgerBaselineEstablished:
                            RecordReconnectGapIfNeeded(
                                observation.KernelTotal,
                                observation.ObservedAt,
                                timeZone,
                                persistence,
                                transaction);
                            break;
                        case TrafficLedgerDelta delta:
                            Add(
                                delta.Report.Categories,
                                observation.ObservedAt,
                                timeZone,
                                persistence,
                                transaction);
                            break;
                        case TrafficLedgerCountersReset:
                            ReplaceCoreSession(
                                _runtimeState.CurrentMihomoVersion ?? "unknown",
                                observation.ObservedAt,
                                "counter_reset",
                                persistence,
                                transaction);
                            break;
                        default:
                            throw new TrafficStatisticsException("本地统计观测状态无效。");
                    }
                }

                _runtimeState = _runtimeState with
                {
                    LastObservedAt = observation.ObservedAt,
                    LastKernelTotal = observation.KernelTotal,
                };
                persistence.SaveRuntimeState(_runtimeState, transaction);
                PruneIfNeeded(timeZone, observation.ObservedAt, persistence, transaction);
            });
            return Snapshot(timeZone, observation.ObservedAt, persistence);
        }, cancellationToken);
    }

    public Task<TrafficStatisticsSnapshot> InterruptMonitoringAsync(
        TrafficSessionEndReason reason,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            var persistence = PreparedPersistence(timeZone, now);
            persistence.Transaction(transaction =>
            {
                var endedAt = _runtimeState.LastObservedAt ?? now;
                if (_runtimeState.CurrentSessionId is Guid sessionId)
                {
                    persistence.CloseCoreSession(
                        sessionId,
                        endedAt,
                        EndReasonName(reason),
                        transaction);
                }

                _runtimeState = _runtimeState with
                {
                    CurrentSessionId = null,
                    CurrentMihomoVersion = null,
                    LastKernelTotal = null,
                };
                persistence.SaveRuntimeState(_runtimeState, transaction);
            });
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

    private async Task<TrafficStatisticsSnapshot> ExecuteAsync(
        Func<TrafficStatisticsSnapshot> operation,
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
        catch (TrafficStatisticsException)
        {
            throw;
        }
        catch (Exception exception) when (
            exception is SqliteException
                or IOException
                or UnauthorizedAccessException
                or OverflowException
                or FormatException)
        {
            throw new TrafficStatisticsException("本地统计数据库暂不可用。", exception);
        }
        finally
        {
            _gate.Release();
        }
    }

    private TrafficLedgerPersistence RequirePersistence()
    {
        if (_persistence is not null)
        {
            return _persistence;
        }

        _persistence = new TrafficLedgerPersistence(_databasePath);
        return _persistence;
    }

    private TrafficLedgerPersistence PreparedPersistence(
        TimeZoneInfo timeZone,
        DateTimeOffset now)
    {
        var persistence = RequirePersistence();
        PrepareIfNeeded(timeZone, now, persistence);
        return persistence;
    }

    private void PrepareIfNeeded(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        TrafficLedgerPersistence persistence)
    {
        if (_isPrepared)
        {
            return;
        }

        _runtimeState = persistence.LoadRuntimeState();
        persistence.Transaction(transaction =>
        {
            var interruptedAt = _runtimeState.LastObservedAt ?? now;
            if (_runtimeState.CurrentSessionId is Guid sessionId)
            {
                persistence.CloseCoreSession(
                    sessionId,
                    interruptedAt,
                    EndReasonName(TrafficSessionEndReason.Recovery),
                    transaction);
            }

            _runtimeState = _runtimeState with
            {
                CurrentSessionId = null,
                CurrentMihomoVersion = null,
                LastKernelTotal = null,
            };
            persistence.SaveRuntimeState(_runtimeState, transaction);
            PruneIfNeeded(timeZone, now, persistence, transaction);
        });
        _isPrepared = true;
    }

    private void OpenCoreSession(
        string version,
        DateTimeOffset date,
        TrafficLedgerPersistence persistence,
        SqliteTransaction transaction)
    {
        var sessionId = Guid.NewGuid();
        persistence.CreateCoreSession(sessionId, version, date, transaction);
        _runtimeState = _runtimeState with
        {
            CurrentSessionId = sessionId,
            CurrentMihomoVersion = version,
            LastKernelTotal = null,
        };
        persistence.SaveRuntimeState(_runtimeState, transaction);
    }

    private void ReplaceCoreSession(
        string version,
        DateTimeOffset date,
        string reason,
        TrafficLedgerPersistence persistence,
        SqliteTransaction transaction)
    {
        if (_runtimeState.CurrentSessionId is Guid sessionId)
        {
            persistence.CloseCoreSession(sessionId, date, reason, transaction);
        }

        OpenCoreSession(version, date, persistence, transaction);
    }

    private void RecordReconnectGapIfNeeded(
        TrafficBytes currentKernelTotal,
        DateTimeOffset observedAt,
        TimeZoneInfo timeZone,
        TrafficLedgerPersistence persistence,
        SqliteTransaction transaction)
    {
        if (_runtimeState.LastKernelTotal is not TrafficBytes previousKernelTotal)
        {
            return;
        }

        var gap = TrafficBytes.NonnegativeDelta(currentKernelTotal, previousKernelTotal);
        if (gap is null)
        {
            ReplaceCoreSession(
                _runtimeState.CurrentMihomoVersion ?? "unknown",
                observedAt,
                "counter_reset",
                persistence,
                transaction);
            return;
        }

        Add(
            CategorizedTrafficBytes.Zero.Adding(gap.Value, TrafficCategory.Unknown),
            observedAt,
            timeZone,
            persistence,
            transaction);
    }

    private void Add(
        CategorizedTrafficBytes categories,
        DateTimeOffset observedAt,
        TimeZoneInfo timeZone,
        TrafficLedgerPersistence persistence,
        SqliteTransaction transaction)
    {
        if (_runtimeState.CurrentSessionId is not Guid sessionId)
        {
            throw new TrafficStatisticsException("缺少本地统计内核会话。");
        }

        persistence.Add(
            categories,
            observedAt,
            timeZone,
            sessionId,
            transaction);
    }

    private void PruneIfNeeded(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        TrafficLedgerPersistence persistence,
        SqliteTransaction transaction)
    {
        var localDay = TrafficLedgerPersistence.LocalDay(now, timeZone);
        if (string.Equals(localDay, _lastPrunedLocalDay, StringComparison.Ordinal))
        {
            return;
        }

        persistence.PruneBuckets(now.AddDays(-365), transaction);
        _lastPrunedLocalDay = localDay;
    }

    private TrafficStatisticsSnapshot Snapshot(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        TrafficLedgerPersistence persistence)
    {
        return new TrafficStatisticsSnapshot(
            persistence.Totals(TrafficLedgerPersistence.LocalDay(now, timeZone)),
            persistence.Totals(),
            _runtimeState.LastObservedAt);
    }

    private static string EndReasonName(TrafficSessionEndReason reason)
    {
        return reason switch
        {
            TrafficSessionEndReason.MonitoringStopped => "monitoring_stopped",
            TrafficSessionEndReason.ApplicationExit => "application_exit",
            TrafficSessionEndReason.TerminalFailure => "terminal_failure",
            TrafficSessionEndReason.Recovery => "recovery",
            _ => throw new TrafficStatisticsException("本地统计结束原因无效。"),
        };
    }
}
