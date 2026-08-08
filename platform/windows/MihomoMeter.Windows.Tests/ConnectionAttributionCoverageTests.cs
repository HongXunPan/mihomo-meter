using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class ConnectionAttributionCoverageTests
{
    [TestMethod]
    public void CountsEachProxyConnectionOnceAndUpgradesAvailability()
    {
        var tracker = new ConnectionAttributionCoverageTracker();

        var initial = tracker.Consume(
        [
            Connection("first", hasHostname: true, hasApplication: false),
            Connection("second", hasHostname: false, hasApplication: true),
        ]);
        var upgraded = tracker.Consume(
        [
            Connection("first", hasHostname: false, hasApplication: true),
        ]);

        Assert.AreEqual(
            new ConnectionAttributionCoverage(2, 1, 1, 0),
            initial);
        Assert.AreEqual(
            new ConnectionAttributionCoverage(2, 1, 2, 1),
            upgraded);
        Assert.AreEqual(0.5, upgraded.HostnameRate);
        Assert.AreEqual(1.0, upgraded.ApplicationRate);
        Assert.AreEqual(0.5, upgraded.FullyIdentifiedRate);
    }

    [TestMethod]
    public void ResetRemovesInMemoryConnectionIdentifiers()
    {
        var tracker = new ConnectionAttributionCoverageTracker();
        _ = tracker.Consume([Connection("connection", true, true)]);

        tracker.Reset();

        Assert.AreEqual(ConnectionAttributionCoverage.Empty, tracker.Consume([]));
    }

    private static ConnectionTrafficSample Connection(
        string id,
        bool hasHostname,
        bool hasApplication)
    {
        return new ConnectionTrafficSample(
            id,
            TrafficBytes.Zero,
            ["Synthetic Proxy"],
            new ConnectionMetadataAvailability(hasHostname, hasApplication));
    }
}
