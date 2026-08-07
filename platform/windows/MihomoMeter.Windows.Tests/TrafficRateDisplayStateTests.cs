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
            false));
        display.Apply(new TrafficMeasurementResult(null, false, false));

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
            false));

        display.Apply(new TrafficMeasurementResult(null, false, true));

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
            false));

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
}
