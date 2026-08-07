using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class ConnectionDeltaTrackerTests
{
    [TestMethod]
    public void SharedFixturesProduceExpectedClassifiedAndUnknownDeltas()
    {
        var proxies = MihomoJsonDecoder.Decode<MihomoProxiesResponse>(
            FixtureLoader.Load("proxies"));
        var initial = MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>(
            FixtureLoader.Load("connections-initial"));
        var next = MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>(
            FixtureLoader.Load("connections-next"));
        var tracker = new ConnectionDeltaTracker();
        var classifier = new ProxyClassifier(proxies.ToCatalog());

        var baseline = tracker.Consume(initial.ToTrafficSnapshot(), classifier);
        var result = tracker.Consume(next.ToTrafficSnapshot(), classifier);

        Assert.AreEqual(ConnectionDeltaStatus.BaselineEstablished, baseline.Status);
        Assert.AreEqual(ConnectionDeltaStatus.Delta, result.Status);
        Assert.IsNotNull(result.Batch);
        Assert.AreEqual(new TrafficBytes(80, 220), result.Batch.Traffic.Categories.Direct);
        Assert.AreEqual(new TrafficBytes(220, 580), result.Batch.Traffic.Categories.Proxy);
        Assert.AreEqual(new TrafficBytes(100, 100), result.Batch.Traffic.Categories.Unknown);
        Assert.AreEqual(1_100.0 / 1_300.0, result.Batch.Traffic.Coverage, 0.000_001);
    }

    [TestMethod]
    public void CountsNewConnectionFromZeroAndRebuildsAfterCounterReset()
    {
        var classifier = new ProxyClassifier(new ProxyCatalog(
            new Dictionary<string, string> { ["Proxy"] = "Vmess" }));
        var tracker = new ConnectionDeltaTracker();
        _ = tracker.Consume(Snapshot(100, 100, []), classifier);

        var delta = tracker.Consume(Snapshot(
            130,
            150,
            [new ConnectionTrafficSample("new", new TrafficBytes(30, 50), ["Proxy"])]), classifier);
        var reset = tracker.Consume(Snapshot(10, 20, []), classifier);

        Assert.IsNotNull(delta.Batch);
        Assert.AreEqual(new TrafficBytes(30, 50), delta.Batch.Traffic.Categories.Proxy);
        Assert.AreEqual(ConnectionDeltaStatus.CountersReset, reset.Status);
    }

    [TestMethod]
    public void AssignsResidualToUnknownWhenConnectionDisappears()
    {
        var classifier = new ProxyClassifier(new ProxyCatalog(
            new Dictionary<string, string> { ["Proxy"] = "Vmess" }));
        var tracker = new ConnectionDeltaTracker();
        _ = tracker.Consume(Snapshot(
            100,
            100,
            [new ConnectionTrafficSample("closed", new TrafficBytes(50, 50), ["Proxy"])]),
            classifier);

        var result = tracker.Consume(Snapshot(120, 150, []), classifier);

        Assert.IsNotNull(result.Batch);
        Assert.AreEqual(new TrafficBytes(20, 50), result.Batch.Traffic.Categories.Unknown);
        Assert.AreEqual(TrafficBytes.Zero, result.Batch.Traffic.Categories.Proxy);
    }

    private static ConnectionTrafficSnapshot Snapshot(
        ulong upload,
        ulong download,
        IReadOnlyList<ConnectionTrafficSample> connections)
    {
        return new ConnectionTrafficSnapshot(new TrafficBytes(upload, download), connections);
    }
}
