using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Statistics;

public sealed partial class SQLiteTrafficLedger
{
    private void PruneIfNeeded(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        TrafficLedgerPersistence persistence,
        SqliteTransaction transaction)
    {
        var localDay = TrafficDailyPersistence.LocalDay(now, timeZone);
        if (string.Equals(localDay, _lastPrunedLocalDay, StringComparison.Ordinal))
        {
            return;
        }

        persistence.Maintenance.PruneBuckets(now.AddDays(-365), transaction);
        _lastPrunedLocalDay = localDay;
    }

    private TrafficStatisticsSnapshot Snapshot(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        TrafficLedgerPersistence persistence)
    {
        var lifetime = persistence.Daily.Totals();
        return new TrafficStatisticsSnapshot(
            persistence.Daily.Totals(TrafficDailyPersistence.LocalDay(now, timeZone)),
            lifetime,
            persistence.Intervals.Load(lifetime.Proxy),
            persistence.Daily.RecentProxyDays(now, timeZone),
            _runtimeState.LastObservedAt);
    }

    private static TrafficIntervalEndReason IntervalEndReason(TrafficSessionEndReason reason)
    {
        return reason switch
        {
            TrafficSessionEndReason.MonitoringStopped =>
                TrafficIntervalEndReason.MonitoringStopped,
            TrafficSessionEndReason.ApplicationExit =>
                TrafficIntervalEndReason.ApplicationExit,
            TrafficSessionEndReason.TerminalFailure =>
                TrafficIntervalEndReason.MonitoringStopped,
            TrafficSessionEndReason.Recovery => TrafficIntervalEndReason.Recovery,
            _ => throw new TrafficStatisticsException("统计任务结束原因无效。"),
        };
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
