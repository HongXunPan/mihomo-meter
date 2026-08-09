using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class ReleaseVersionTests
{
    [TestMethod]
    public void ParsesAndComparesStrictThreePartVersions()
    {
        Assert.IsTrue(ReleaseVersion.TryParse("1.2.3", out var version));
        Assert.AreEqual("1.2.3", version.ToString());
        Assert.IsTrue(version.CompareTo(new ReleaseVersion(1, 2, 2)) > 0);
        Assert.IsTrue(version.CompareTo(new ReleaseVersion(1, 3, 0)) < 0);
    }

    [TestMethod]
    public void RejectsLeadingZerosSuffixesAndOverflow()
    {
        Assert.IsFalse(ReleaseVersion.TryParse("01.2.3", out _));
        Assert.IsFalse(ReleaseVersion.TryParse("1.2", out _));
        Assert.IsFalse(ReleaseVersion.TryParse("1.2.3-beta", out _));
        Assert.IsFalse(ReleaseVersion.TryParse("2147483648.0.0", out _));
    }

    [TestMethod]
    public void ReadsFirstThreeAssemblyVersionParts()
    {
        Assert.AreEqual(
            new ReleaseVersion(2, 4, 6),
            ReleaseVersion.FromAssemblyVersion(new Version(2, 4, 6, 8)));
    }
}
