using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class TrafficIntervalInputTests
{
    [TestMethod]
    public void NormalizesNameAndOptionalNote()
    {
        Assert.AreEqual("下载镜像", TrafficIntervalInput.NormalizeName("  下载镜像  "));
        Assert.AreEqual("晚间", TrafficIntervalInput.NormalizeNote("  晚间  "));
        Assert.IsNull(TrafficIntervalInput.NormalizeNote("  \r\n  "));
        Assert.IsNull(TrafficIntervalInput.NormalizeNote(null));
    }

    [TestMethod]
    public void RejectsEmptyName()
    {
        _ = Assert.ThrowsExactly<ArgumentException>(() =>
            TrafficIntervalInput.NormalizeName(" \r\n "));
    }
}
