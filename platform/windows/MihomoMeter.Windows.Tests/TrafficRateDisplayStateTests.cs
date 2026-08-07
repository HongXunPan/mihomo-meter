using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class TrafficRateDisplayStateTests
{
    [TestMethod]
    public void RetainsLatestCompleteWindowAcrossPartialFrames()
    {
        var display = new TrafficRateDisplayState();
        var rates = CreateRates(120, 340);

        display.Apply(new TrafficMeasurementResult(
            new TrafficRateWindow(rates, rates, 0.75),
            false,
            false,
            CreateObservation()));
        display.Apply(new TrafficMeasurementResult(null, false, false, CreateObservation()));

        Assert.AreEqual(rates, display.Rates);
        Assert.AreEqual(0.75, display.Coverage);
    }

    [TestMethod]
    public void ClearsLatestWindowWhenCountersReset()
    {
        var display = new TrafficRateDisplayState();
        var rates = CreateRates(120, 340);
        display.Apply(new TrafficMeasurementResult(
            new TrafficRateWindow(rates, rates, 1),
            false,
            false,
            CreateObservation()));

        display.Apply(new TrafficMeasurementResult(
            null,
            false,
            true,
            CreateObservation(new TrafficLedgerCountersReset())));

        Assert.IsNull(display.Rates);
        Assert.IsNull(display.Coverage);
    }

    [TestMethod]
    public void ClearsLatestWindowWhenStreamBecomesStale()
    {
        var display = new TrafficRateDisplayState();
        var rates = CreateRates(120, 340);
        display.Apply(new TrafficMeasurementResult(
            new TrafficRateWindow(rates, rates, 1),
            false,
            false,
            CreateObservation()));

        display.Clear();

        Assert.IsNull(display.Rates);
        Assert.IsNull(display.Coverage);
    }

    private static CategorizedTrafficRates CreateRates(ulong upload, ulong download)
    {
        return new CategorizedTrafficRates(
            new TrafficRate(upload, download),
            TrafficRate.Zero,
            TrafficRate.Zero,
            TrafficRate.Zero);
    }

    private static TrafficLedgerObservation CreateObservation(
        TrafficLedgerTransition? transition = null)
    {
        return new TrafficLedgerObservation(
            DateTimeOffset.UnixEpoch,
            TrafficBytes.Zero,
            transition ?? new TrafficLedgerBaselineEstablished());
    }
}
