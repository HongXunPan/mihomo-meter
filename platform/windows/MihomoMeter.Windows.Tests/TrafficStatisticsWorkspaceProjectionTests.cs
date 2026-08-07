using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class TrafficStatisticsWorkspaceProjectionTests
{
    [TestMethod]
    public void FiltersActiveHistoryAndAllWithoutChangingOrder()
    {
        var intervals = new[]
        {
            Interval("进行中", TrafficIntervalStatus.Active),
            Interval("已完成", TrafficIntervalStatus.Completed),
            Interval("已中断", TrafficIntervalStatus.Interrupted),
        };

        CollectionAssert.AreEqual(
            new[] { "进行中" },
            Names(TrafficStatisticsWorkspaceProjection.FilterIntervals(
                intervals,
                TrafficStatisticsIntervalFilter.Active)));
        CollectionAssert.AreEqual(
            new[] { "已完成", "已中断" },
            Names(TrafficStatisticsWorkspaceProjection.FilterIntervals(
                intervals,
                TrafficStatisticsIntervalFilter.History)));
        CollectionAssert.AreEqual(
            new[] { "进行中", "已完成", "已中断" },
            Names(TrafficStatisticsWorkspaceProjection.FilterIntervals(
                intervals,
                TrafficStatisticsIntervalFilter.All)));
    }

    [TestMethod]
    public void ProvidesSuggestedNameAndActiveCount()
    {
        var intervals = new[]
        {
            Interval("一", TrafficIntervalStatus.Active),
            Interval("二", TrafficIntervalStatus.Completed),
            Interval("三", TrafficIntervalStatus.Active),
        };

        Assert.AreEqual(
            "统计任务 4",
            TrafficStatisticsWorkspaceProjection.SuggestedIntervalName(intervals));
        Assert.AreEqual(
            2,
            TrafficStatisticsWorkspaceProjection.ActiveIntervalCount(intervals));
    }

    [TestMethod]
    public void SummarizesDailyRangeAndNormalizesStackedBarsAgainstPeakTotal()
    {
        var days = new[]
        {
            new TrafficDailyTotal("2026-08-06", new TrafficBytes(10, 30)),
            new TrafficDailyTotal("2026-08-07", TrafficBytes.Zero),
            new TrafficDailyTotal("2026-08-08", new TrafficBytes(20, 80)),
        };

        var range = TrafficStatisticsWorkspaceProjection.DailyRange(days);

        Assert.AreEqual(new TrafficBytes(30, 110), range.Total);
        Assert.AreEqual("2026-08-08", range.PeakDay?.LocalDay);
        Assert.AreEqual(new TrafficDailyAxisTicks(100, 75, 50, 25), range.AxisTicks);
        Assert.AreEqual(3, range.Points.Count);
        Assert.AreEqual(0.1, range.Points[0].UploadFraction, 0.0001);
        Assert.AreEqual(0.3, range.Points[0].DownloadFraction, 0.0001);
        Assert.AreEqual(0.0, range.Points[1].UploadFraction);
        Assert.AreEqual(0.0, range.Points[1].DownloadFraction);
        Assert.AreEqual(0.2, range.Points[2].UploadFraction, 0.0001);
        Assert.AreEqual(0.8, range.Points[2].DownloadFraction, 0.0001);
    }

    [TestMethod]
    public void KeepsThirtyZeroDaysAsVisibleZeroPoints()
    {
        var days = Enumerable.Range(1, 30)
            .Select(day => new TrafficDailyTotal(
                $"2026-07-{day:00}",
                TrafficBytes.Zero))
            .ToArray();

        var range = TrafficStatisticsWorkspaceProjection.DailyRange(days);

        Assert.AreEqual(30, range.Points.Count);
        Assert.AreEqual(TrafficBytes.Zero, range.Total);
        Assert.AreEqual("2026-07-01", range.PeakDay?.LocalDay);
        Assert.AreEqual(new TrafficDailyAxisTicks(0, 0, 0, 0), range.AxisTicks);
        Assert.IsTrue(range.Points.All(point =>
            point.UploadFraction == 0 && point.DownloadFraction == 0));
        CollectionAssert.AreEqual(
            new[] { 0, 7, 14, 21, 29 },
            range.Points
                .Select((point, index) => (point, index))
                .Where(value => value.point.ShowsAxisLabel)
                .Select(value => value.index)
                .ToArray());
    }

    private static TrafficInterval Interval(string name, TrafficIntervalStatus status)
    {
        var startedAt = DateTimeOffset.FromUnixTimeSeconds(1_000);
        DateTimeOffset? endedAt = status == TrafficIntervalStatus.Active
            ? null
            : startedAt.AddMinutes(1);
        TrafficIntervalEndReason? endReason = status switch
        {
            TrafficIntervalStatus.Active => null,
            TrafficIntervalStatus.Completed => TrafficIntervalEndReason.User,
            _ => TrafficIntervalEndReason.Recovery,
        };
        return new TrafficInterval(
            Guid.NewGuid(),
            name,
            null,
            status,
            startedAt,
            endedAt,
            endReason,
            new TrafficBytes(1, 2));
    }

    private static string[] Names(IReadOnlyList<TrafficInterval> intervals)
    {
        return intervals.Select(interval => interval.Name).ToArray();
    }
}
