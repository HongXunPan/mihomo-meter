using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class LiveConnectionProjectionTests
{
    [TestMethod]
    public void FiltersAndSortsConnectionsWithoutExposingIdentifiers()
    {
        var connections = new[]
        {
            Connection("private-id-1", "alpha.test", "Browser", 10, 20),
            Connection("private-id-2", "beta.test", "Terminal", 40, 50),
        };

        var result = LiveConnectionProjection.Connections(connections, "terminal");

        Assert.AreEqual(1, result.Count);
        Assert.AreEqual("Terminal", result[0].Metadata.ApplicationName);
    }

    [TestMethod]
    public void GroupsByApplicationAndCountsDistinctHostnames()
    {
        var groups = LiveConnectionProjection.Groups(
            [
                Connection("first", "alpha.test", "Browser", 10, 20),
                Connection("second", "beta.test", "Browser", 30, 40),
            ],
            LiveConnectionViewMode.Application,
            string.Empty);

        Assert.AreEqual(1, groups.Count);
        Assert.AreEqual("Browser", groups[0].Name);
        Assert.AreEqual(2, groups[0].RelatedCount);
        Assert.AreEqual(2, groups[0].ConnectionCount);
        Assert.AreEqual(new TrafficRate(40, 60), groups[0].Rate);
    }

    [TestMethod]
    public void ProducesFiveStableTopSlotsAndExcludesIdleConnections()
    {
        var slots = LiveConnectionProjection.TopSlots(
        [
            Connection("idle", "idle.test", "Idle", 0, 0),
            Connection("active", "active.test", "Browser", 10, 20),
        ]);

        Assert.AreEqual(LiveConnectionProjection.TopSlotCount, slots.Count);
        Assert.AreEqual("active", slots[0]?.Id);
        Assert.IsNull(slots[1]);
        Assert.IsNull(slots[4]);
    }

    [TestMethod]
    public void ExplainsDisabledProcessMatchingMode()
    {
        var diagnostic = ApplicationIdentificationDiagnostic.Create(
            MihomoProcessMatchingMode.Off,
            new ConnectionAttributionCoverage(10, 9, 2, 2));

        Assert.IsTrue(diagnostic.IsWarning);
        StringAssert.Contains(diagnostic.Title, "2/10");
        StringAssert.Contains(diagnostic.Detail, "关闭");
    }

    private static LiveTrafficConnection Connection(
        string id,
        string? hostname,
        string? application,
        ulong uploadRate,
        ulong downloadRate)
    {
        return new LiveTrafficConnection(
            id,
            new ConnectionMetadata(hostname, application),
            new TrafficRate(uploadRate, downloadRate),
            new TrafficBytes(uploadRate * 10, downloadRate * 10),
            DateTimeOffset.Parse("2026-08-08T00:00:00Z"));
    }
}
