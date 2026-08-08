using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class ConnectionRateAggregatorTests
{
    [TestMethod]
    public void EstablishesBaselineThenSmoothsTwoRateWindows()
    {
        var aggregator = new ConnectionRateAggregator();
        aggregator.EstablishBaseline([Connection("first", 100, 200)]);

        var first = aggregator.Consume(
            [Connection("first", 300, 600)],
            [Delta("first", 200, 400)],
            1);
        var second = aggregator.Consume(
            [Connection("first", 400, 800)],
            [Delta("first", 100, 200)],
            1);

        Assert.AreEqual(new TrafficRate(200, 400), first[0].Rate);
        Assert.AreEqual(new TrafficRate(150, 300), second[0].Rate);
        Assert.AreEqual(new TrafficBytes(400, 800), second[0].CumulativeBytes);
    }

    [TestMethod]
    public void RemovesClosedConnectionsAndClearsAllStateOnReset()
    {
        var aggregator = new ConnectionRateAggregator();
        aggregator.EstablishBaseline([Connection("closed", 1, 1)]);

        var afterClose = aggregator.Consume([], [], 1);
        aggregator.Reset();

        Assert.AreEqual(0, afterClose.Count);
        Assert.AreEqual(0, aggregator.LiveConnections.Count);
    }

    private static ConnectionTrafficSample Connection(
        string id,
        ulong upload,
        ulong download)
    {
        return new ConnectionTrafficSample(
            id,
            new TrafficBytes(upload, download),
            ["Synthetic Proxy"],
            Metadata: new ConnectionMetadata("example.test", "Synthetic"));
    }

    private static ConnectionTrafficDelta Delta(
        string id,
        ulong upload,
        ulong download)
    {
        return new ConnectionTrafficDelta(
            id,
            TrafficCategory.Proxy,
            new TrafficBytes(upload, download),
            new TrafficBytes(upload, download),
            new ConnectionMetadata("example.test", "Synthetic"),
            null);
    }
}
