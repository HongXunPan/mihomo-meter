using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class QuotaRelativeTimeFormatterTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 8, 29, 12, 0, 0, TimeSpan.Zero);

    [TestMethod]
    [DataRow(-59, "刚刚")]
    [DataRow(59, "即将")]
    [DataRow(-61, "1 分钟前")]
    [DataRow(3_601, "1 小时后")]
    [DataRow(-259_200, "3 天前")]
    public void UsesStableCrossPlatformRelativeUnits(int seconds, string expected)
    {
        Assert.AreEqual(
            expected,
            QuotaRelativeTimeFormatter.Format(Now.AddSeconds(seconds), Now));
    }
}
