using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public sealed record TrafficStatisticsQuickTaskSlot(
    int Index,
    TrafficInterval? Interval);

public sealed record TrafficStatisticsQuickTaskSnapshot(
    int ActiveCount,
    IReadOnlyList<TrafficStatisticsQuickTaskSlot> Slots,
    int AdditionalCount);

public static class TrafficStatisticsQuickTaskProjection
{
    public const int SlotCount = 5;

    public static TrafficStatisticsQuickTaskSnapshot Project(
        IReadOnlyList<TrafficInterval> intervals,
        TimeZoneInfo timeZone,
        DateTimeOffset now)
    {
        ArgumentNullException.ThrowIfNull(intervals);
        ArgumentNullException.ThrowIfNull(timeZone);

        var activeIntervals = intervals
            .Where(interval => interval.Status == TrafficIntervalStatus.Active)
            .OrderByDescending(interval => interval.StartedAt)
            .ToArray();
        var localToday = LocalDay(now, timeZone);
        var todayEndedIntervals = intervals
            .Where(interval => interval.Status != TrafficIntervalStatus.Active)
            .Where(interval => interval.EndedAt is DateTimeOffset endedAt
                && LocalDay(endedAt, timeZone) == localToday)
            .OrderByDescending(interval => interval.EndedAt)
            .ToArray();
        var candidates = activeIntervals
            .Concat(todayEndedIntervals)
            .ToArray();
        var slots = Enumerable.Range(0, SlotCount)
            .Select(index => new TrafficStatisticsQuickTaskSlot(
                index,
                index < candidates.Length ? candidates[index] : null))
            .ToArray();

        return new TrafficStatisticsQuickTaskSnapshot(
            activeIntervals.Length,
            Array.AsReadOnly(slots),
            Math.Max(candidates.Length - SlotCount, 0));
    }

    private static DateOnly LocalDay(DateTimeOffset value, TimeZoneInfo timeZone)
    {
        return DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(value, timeZone).Date);
    }
}
