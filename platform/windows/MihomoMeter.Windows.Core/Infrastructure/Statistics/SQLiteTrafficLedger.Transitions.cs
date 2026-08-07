using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Statistics;

public sealed partial class SQLiteTrafficLedger
{
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
}
