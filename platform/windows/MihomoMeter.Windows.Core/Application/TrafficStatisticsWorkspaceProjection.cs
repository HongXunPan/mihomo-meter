using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public enum TrafficStatisticsIntervalFilter
{
    Active,
    History,
    All,
}

public sealed record TrafficDailyChartPoint(
    string LocalDay,
    TrafficBytes Bytes,
    double UploadFraction,
    double DownloadFraction);

public sealed record TrafficDailyRangeSummary(
    TrafficBytes Total,
    TrafficDailyTotal? PeakDay,
    IReadOnlyList<TrafficDailyChartPoint> Points);

public static class TrafficStatisticsWorkspaceProjection
{
    public static string SuggestedIntervalName(IReadOnlyList<TrafficInterval> intervals)
    {
        return $"统计任务 {intervals.Count + 1}";
    }

    public static int ActiveIntervalCount(IReadOnlyList<TrafficInterval> intervals)
    {
        return intervals.Count(interval => interval.Status == TrafficIntervalStatus.Active);
    }

    public static IReadOnlyList<TrafficInterval> FilterIntervals(
        IReadOnlyList<TrafficInterval> intervals,
        TrafficStatisticsIntervalFilter filter)
    {
        return filter switch
        {
            TrafficStatisticsIntervalFilter.Active => intervals
                .Where(interval => interval.Status == TrafficIntervalStatus.Active)
                .ToArray(),
            TrafficStatisticsIntervalFilter.History => intervals
                .Where(interval => interval.Status != TrafficIntervalStatus.Active)
                .ToArray(),
            TrafficStatisticsIntervalFilter.All => intervals.ToArray(),
            _ => throw new ArgumentOutOfRangeException(nameof(filter)),
        };
    }

    public static TrafficDailyRangeSummary DailyRange(
        IReadOnlyList<TrafficDailyTotal> days)
    {
        var total = TrafficBytes.Zero;
        TrafficDailyTotal? peakDay = null;
        foreach (var day in days)
        {
            total = TrafficBytes.Add(total, day.Bytes);
            if (peakDay is null || day.Bytes.Total > peakDay.Bytes.Total)
            {
                peakDay = day;
            }
        }

        var maximum = peakDay?.Bytes.Total ?? 0;
        var points = days
            .Select(day => new TrafficDailyChartPoint(
                day.LocalDay,
                day.Bytes,
                maximum == 0 ? 0 : (double)day.Bytes.Upload / maximum,
                maximum == 0 ? 0 : (double)day.Bytes.Download / maximum))
            .ToArray();
        return new TrafficDailyRangeSummary(total, peakDay, points);
    }
}
