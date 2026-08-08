using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class ConnectionAnalyticsProjectionTests
{
    [TestMethod]
    public void RankingsAggregateAndApplyExactCrossFilters()
    {
        var records = new[]
        {
            Record("Browser", "a.test", 10),
            Record("Browser", "b.test", 20),
            Record("Terminal", "a.test", 30),
        };

        var applications = ConnectionAnalyticsWorkspaceProjection.ApplicationRanking(
            records,
            null,
            "a.test");
        var hostnames = ConnectionAnalyticsWorkspaceProjection.HostnameRanking(
            records,
            "Browser",
            null);

        CollectionAssert.AreEqual(
            new[] { "Terminal", "Browser" },
            applications.Select(item => item.Name).ToArray());
        Assert.AreEqual((ulong)30, applications[0].Bytes.Total);
        CollectionAssert.AreEqual(
            new[] { "b.test", "a.test" },
            hostnames.Select(item => item.Name).ToArray());
    }

    [TestMethod]
    public void TrendPeakUsesLatestDayWhenValuesTie()
    {
        var trend = new ConnectionAnalyticsTrend(
        [
            new ConnectionAnalyticsTrendPoint("2026-08-06", new TrafficBytes(5, 5)),
            new ConnectionAnalyticsTrendPoint("2026-08-07", TrafficBytes.Zero),
            new ConnectionAnalyticsTrendPoint("2026-08-08", new TrafficBytes(4, 6)),
        ]);

        Assert.AreEqual("2026-08-08", trend.PeakPoint?.LocalDay);
        Assert.AreEqual("2026-08-08", trend.DefaultSelectedLocalDay);
        Assert.AreEqual(2, trend.ActiveDayCount);
    }

    [TestMethod]
    public void RecordingCoverageIsUnavailableWhenCoreProxyIsZero()
    {
        var coverage = new ConnectionAnalyticsRecordingCoverage(
            new TrafficBytes(1, 2),
            TrafficBytes.Zero);

        Assert.IsNull(coverage.Rate);
    }

    [TestMethod]
    public void TrendRequiresAtLeastOneExactDimension()
    {
        _ = Assert.ThrowsExactly<ArgumentException>(() =>
            new ConnectionAnalyticsTrendQuery());
    }

    private static ConnectionAttributionRecord Record(
        string application,
        string hostname,
        ulong total)
    {
        return new ConnectionAttributionRecord(
            "2026-08-08",
            application,
            hostname,
            new TrafficBytes(total, 0));
    }
}
