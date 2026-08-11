using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class MihomoMeterSharedCoreTests
{
    [TestMethod]
    public void AbiVersionMatchesP0Contract()
    {
        Assert.AreEqual(1U, MihomoMeterSharedCore.AbiVersion);
    }

    [TestMethod]
    [DataRow(0UL, 0.0, SharedTrafficUnit.Bytes, 0U)]
    [DataRow(1_500UL, 1.5, SharedTrafficUnit.Kilobytes, 2U)]
    [DataRow(10_000UL, 10.0, SharedTrafficUnit.Kilobytes, 1U)]
    [DataRow(100_000UL, 100.0, SharedTrafficUnit.Kilobytes, 0U)]
    [DataRow(1_000_000_000_000UL, 1.0, SharedTrafficUnit.Terabytes, 2U)]
    public void TrafficScalingUsesDecimalUnitsAndMacPrecision(
        ulong bytes,
        double expectedValue,
        SharedTrafficUnit expectedUnit,
        uint expectedDecimalPlaces)
    {
        var result = MihomoMeterSharedCore.ScaleTraffic(bytes);

        Assert.AreEqual(expectedValue, result.Value, double.Epsilon);
        Assert.AreEqual(expectedUnit, result.Unit);
        Assert.AreEqual(expectedDecimalPlaces, result.DecimalPlaces);
    }
}
