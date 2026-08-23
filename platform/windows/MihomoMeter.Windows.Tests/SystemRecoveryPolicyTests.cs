using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class SystemRecoveryPolicyTests
{
    [TestMethod]
    public void FirstBlockerPausesAndLastBlockerResumes()
    {
        var policy = new SystemRecoveryPolicy();

        Assert.AreEqual(
            SystemRecoveryAction.Pause,
            policy.Update(SystemEnvironmentBlocker.Sleep, true));
        Assert.IsNull(policy.Update(SystemEnvironmentBlocker.NetworkUnavailable, true));
        Assert.IsNull(policy.Update(SystemEnvironmentBlocker.Sleep, false));
        Assert.AreEqual(
            SystemRecoveryAction.Resume,
            policy.Update(SystemEnvironmentBlocker.NetworkUnavailable, false));
        Assert.IsTrue(policy.IsAvailable);
    }

    [TestMethod]
    public void DuplicateEnvironmentEventDoesNotRepeatAction()
    {
        var policy = new SystemRecoveryPolicy();

        Assert.AreEqual(
            SystemRecoveryAction.Pause,
            policy.Update(SystemEnvironmentBlocker.InactiveSession, true));
        Assert.IsNull(policy.Update(SystemEnvironmentBlocker.InactiveSession, true));
        Assert.AreEqual(
            SystemRecoveryAction.Resume,
            policy.Update(SystemEnvironmentBlocker.InactiveSession, false));
        Assert.IsNull(policy.Update(SystemEnvironmentBlocker.InactiveSession, false));
    }
}
