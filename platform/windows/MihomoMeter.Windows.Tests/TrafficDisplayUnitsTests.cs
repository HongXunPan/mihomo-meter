using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class TrafficDisplayUnitsTests
{
    [TestMethod]
    [DataRow(0UL, "0 B")]
    [DataRow(999UL, "999 B")]
    [DataRow(1_000UL, "1.00 KB")]
    [DataRow(10_000UL, "10.0 KB")]
    [DataRow(100_000UL, "100 KB")]
    [DataRow(1_000_000UL, "1.00 MB")]
    [DataRow(1_000_000_000UL, "1.00 GB")]
    [DataRow(1_000_000_000_000UL, "1.00 TB")]
    public void ByteCountUsesDecimalUnitsAndMacPrecision(ulong bytes, string expected)
    {
        Assert.AreEqual(expected, TrafficDisplayUnits.ByteCount(bytes));
    }

    [TestMethod]
    [DataRow(0UL, "0 B/s")]
    [DataRow(1_500UL, "1.50 KB/s")]
    [DataRow(10_000UL, "10.0 KB/s")]
    [DataRow(100_000UL, "100 KB/s")]
    public void RateUsesDecimalUnitsAndMacPrecision(ulong bytes, string expected)
    {
        Assert.AreEqual(expected, TrafficDisplayUnits.Rate(bytes));
    }

    [TestMethod]
    [DataRow(0UL, "0B/s")]
    [DataRow(1_500UL, "1.50K/s")]
    [DataRow(10_000UL, "10.0K/s")]
    [DataRow(100_000UL, "100K/s")]
    public void CompactRateUsesShortUnitsAndMacPrecision(ulong bytes, string expected)
    {
        Assert.AreEqual(expected, TrafficDisplayUnits.CompactRate(bytes));
    }

    [TestMethod]
    public void CompactRateUsesPlaceholderForMissingValue()
    {
        Assert.AreEqual("--", TrafficDisplayUnits.CompactRate(null));
    }
}
