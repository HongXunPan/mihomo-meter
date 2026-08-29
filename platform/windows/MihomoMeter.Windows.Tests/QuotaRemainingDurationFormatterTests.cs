using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class QuotaRemainingDurationFormatterTests
{
    [TestMethod]
    [DataRow(0, "0 天")]
    [DataRow(59, "59 天")]
    [DataRow(60, "2 个月")]
    [DataRow(364, "12 个月")]
    [DataRow(365, "1 年")]
    [DataRow(400, "1 年 1 个月")]
    [DataRow(729, "2 年")]
    [DataRow(3_712, "10 年 2 个月")]
    public void FormatDaysUsesUnifiedHumanReadableUnits(int days, string expected)
    {
        Assert.AreEqual(expected, QuotaRemainingDurationFormatter.FormatDays(days));
    }
}
