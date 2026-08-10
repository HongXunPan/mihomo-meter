using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class TrafficDisplayUnitsTests
{
    [DataTestMethod]
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
}
