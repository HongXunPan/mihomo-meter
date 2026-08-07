using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class TrafficRateAggregatorTests
{
    [TestMethod]
    public void UsesOneSecondWindowAndTwoWindowAverage()
    {
        var aggregator = new TrafficRateAggregator();

        var first = aggregator.Consume(Report(200, 400), 1);
        var second = aggregator.Consume(Report(400, 800), 1);

        Assert.IsNotNull(first);
        Assert.IsNotNull(second);
        Assert.AreEqual(new TrafficRate(200, 400), first.Smoothed.Proxy);
        Assert.AreEqual(new TrafficRate(300, 600), second.Smoothed.Proxy);
    }

    [TestMethod]
    public void WaitsForCompleteWindowAndResetClearsAverage()
    {
        var aggregator = new TrafficRateAggregator();

        Assert.IsNull(aggregator.Consume(Report(50, 100), 0.5));
        var completed = aggregator.Consume(Report(50, 100), 0.5);
        aggregator.Reset();
        var afterReset = aggregator.Consume(Report(300, 600), 1);

        Assert.IsNotNull(completed);
        Assert.IsNotNull(afterReset);
        Assert.AreEqual(new TrafficRate(100, 200), completed.Raw.Proxy);
        Assert.AreEqual(new TrafficRate(300, 600), afterReset.Smoothed.Proxy);
    }

    [TestMethod]
    public void AggregatesCoverageAcrossPartialFrames()
    {
        var aggregator = new TrafficRateAggregator();
        var halfCovered = new TrafficDeltaReport(
            new TrafficBytes(50, 50),
            CategorizedTrafficBytes.Zero.Adding(
                new TrafficBytes(25, 25),
                TrafficCategory.Proxy));
        var fullyCovered = Report(50, 50);

        Assert.IsNull(aggregator.Consume(halfCovered, 0.5));
        var completed = aggregator.Consume(fullyCovered, 0.5);

        Assert.IsNotNull(completed);
        Assert.AreEqual(0.75, completed.Coverage, 0.000_001);
    }

    [TestMethod]
    public void IgnoresInvalidIntervalsWithoutPollutingNextWindow()
    {
        var aggregator = new TrafficRateAggregator();

        Assert.IsNull(aggregator.Consume(Report(500, 500), 0));
        Assert.IsNull(aggregator.Consume(Report(500, 500), double.NaN));
        var valid = aggregator.Consume(Report(100, 200), 1);

        Assert.IsNotNull(valid);
        Assert.AreEqual(new TrafficRate(100, 200), valid.Raw.Proxy);
    }

    [TestMethod]
    public void TrafficByteAdditionSaturatesAtUnsignedMaximum()
    {
        var result = TrafficBytes.Add(
            new TrafficBytes(ulong.MaxValue - 1, ulong.MaxValue),
            new TrafficBytes(10, 1));

        Assert.AreEqual(new TrafficBytes(ulong.MaxValue, ulong.MaxValue), result);
    }

    private static TrafficDeltaReport Report(ulong upload, ulong download)
    {
        return new TrafficDeltaReport(
            new TrafficBytes(upload, download),
            CategorizedTrafficBytes.Zero.Adding(
                new TrafficBytes(upload, download),
                TrafficCategory.Proxy));
    }
}
