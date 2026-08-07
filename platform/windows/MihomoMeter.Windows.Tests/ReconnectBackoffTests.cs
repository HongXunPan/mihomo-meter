using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class ReconnectBackoffTests
{
    [TestMethod]
    public void DoublesDelayAndCapsAtThirtySeconds()
    {
        var backoff = new ReconnectBackoff();
        var delays = Enumerable.Range(0, 8)
            .Select(_ => backoff.NextDelaySeconds())
            .ToArray();

        CollectionAssert.AreEqual(new[] { 1, 2, 4, 8, 16, 30, 30, 30 }, delays);
    }

    [TestMethod]
    public void ResetStartsSequenceAgain()
    {
        var backoff = new ReconnectBackoff();
        _ = backoff.NextDelaySeconds();
        _ = backoff.NextDelaySeconds();

        backoff.Reset();

        Assert.AreEqual(1, backoff.NextDelaySeconds());
    }
}
