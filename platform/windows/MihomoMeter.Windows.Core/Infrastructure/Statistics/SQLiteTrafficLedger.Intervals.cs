using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Statistics;

public sealed partial class SQLiteTrafficLedger
{
    public Task<TrafficStatisticsSnapshot> StartIntervalAsync(
        string name,
        string? note,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            var normalizedName = TrafficIntervalInput.NormalizeName(name);
            var normalizedNote = TrafficIntervalInput.NormalizeNote(note);
            var persistence = PreparedPersistence(timeZone, now);
            var baseline = persistence.Daily.Totals().Proxy;
            persistence.Transaction(transaction => persistence.Intervals.Insert(
                Guid.NewGuid(),
                normalizedName,
                normalizedNote,
                now,
                baseline,
                transaction));
            return Snapshot(timeZone, now, persistence);
        }, cancellationToken);
    }

    public Task<TrafficStatisticsSnapshot> StopIntervalAsync(
        Guid id,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            var persistence = PreparedPersistence(timeZone, now);
            var baseline = persistence.Daily.Totals().Proxy;
            _ = persistence.Intervals.Load(baseline);
            persistence.Transaction(transaction =>
                persistence.Intervals.Complete(id, now, baseline, transaction));
            return Snapshot(timeZone, now, persistence);
        }, cancellationToken);
    }

    public Task<TrafficStatisticsSnapshot> RenameIntervalAsync(
        Guid id,
        string name,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            var normalizedName = TrafficIntervalInput.NormalizeName(name);
            var persistence = PreparedPersistence(timeZone, now);
            persistence.Transaction(transaction =>
                persistence.Intervals.Rename(id, normalizedName, transaction));
            return Snapshot(timeZone, now, persistence);
        }, cancellationToken);
    }

    public Task<TrafficStatisticsSnapshot> DeleteIntervalAsync(
        Guid id,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            var persistence = PreparedPersistence(timeZone, now);
            persistence.Transaction(transaction =>
                persistence.Intervals.Delete(id, transaction));
            return Snapshot(timeZone, now, persistence);
        }, cancellationToken);
    }

    public Task<TrafficStatisticsSnapshot> InterruptActiveIntervalsAsync(
        TrafficIntervalEndReason reason,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            if (reason == TrafficIntervalEndReason.User)
            {
                throw new TrafficIntervalOperationException("用户停止必须指定单个统计任务。");
            }

            var persistence = PreparedPersistence(timeZone, now);
            var baseline = persistence.Daily.Totals().Proxy;
            _ = persistence.Intervals.Load(baseline);
            persistence.Transaction(transaction => persistence.Intervals.InterruptActive(
                _runtimeState.LastObservedAt ?? now,
                baseline,
                reason,
                transaction));
            return Snapshot(timeZone, now, persistence);
        }, cancellationToken);
    }

    public Task<TrafficStatisticsSnapshot> ClearAsync(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        return ExecuteAsync(() =>
        {
            var persistence = PreparedPersistence(timeZone, now);
            persistence.Transaction(persistence.Maintenance.Reset);
            _runtimeState = new TrafficLedgerRuntimeState();
            _lastPrunedLocalDay = null;
            _isPrepared = true;
            return new TrafficStatisticsSnapshot(
                CategorizedTrafficBytes.Zero,
                CategorizedTrafficBytes.Zero,
                Array.Empty<TrafficInterval>(),
                TrafficDailyPersistence.EmptyRecentProxyDays(now, timeZone),
                null);
        }, cancellationToken);
    }
}
