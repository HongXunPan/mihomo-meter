using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class CrashRecoveryRestartPolicyTests
{
    private static readonly DateTimeOffset Now = new(
        2026,
        8,
        23,
        12,
        0,
        0,
        TimeSpan.Zero);

    [TestMethod]
    public void RegularLaunchKeepsExistingState()
    {
        var state = new CrashRecoveryRestartState(
            null,
            null,
            Now - TimeSpan.FromHours(1));

        var decision = CrashRecoveryRestartPolicy.EvaluateStartup(
            ["--startup"],
            state,
            Now);

        Assert.AreEqual(
            CrashRecoveryStartupDisposition.RegularLaunch,
            decision.Disposition);
        Assert.AreEqual(state, decision.State);
    }

    [TestMethod]
    public void FreshMatchingTokenAllowsOneRecoveryLaunch()
    {
        const string token = "11111111111111111111111111111111";
        var state = new CrashRecoveryRestartState(
            token,
            Now - TimeSpan.FromMinutes(1),
            null);

        var decision = CrashRecoveryRestartPolicy.EvaluateStartup(
            [$"{CrashRecoveryRestartPolicy.RecoveryArgumentPrefix}{token}"],
            state,
            Now);

        Assert.AreEqual(
            CrashRecoveryStartupDisposition.RecoveryAllowed,
            decision.Disposition);
        Assert.IsNull(decision.State.PendingToken);
        Assert.IsNull(decision.State.PendingRegisteredAtUtc);
        Assert.AreEqual(Now, decision.State.LastRecoveryStartedAtUtc);
    }

    [TestMethod]
    public void SecondRecoveryInsideWindowIsSuppressed()
    {
        const string token = "22222222222222222222222222222222";
        var state = new CrashRecoveryRestartState(
            token,
            Now - TimeSpan.FromMinutes(1),
            Now - TimeSpan.FromMinutes(5));

        var decision = CrashRecoveryRestartPolicy.EvaluateStartup(
            [$"{CrashRecoveryRestartPolicy.RecoveryArgumentPrefix}{token}"],
            state,
            Now);

        Assert.AreEqual(
            CrashRecoveryStartupDisposition.RecoverySuppressed,
            decision.Disposition);
        Assert.IsNull(decision.State.PendingToken);
        Assert.AreEqual(
            TimeSpan.FromMinutes(5),
            CrashRecoveryRestartPolicy.RegistrationDelay(state, Now));
    }

    [TestMethod]
    public void ExpiredOrMismatchedTokenIsRejected()
    {
        const string pendingToken = "33333333333333333333333333333333";
        const string suppliedToken = "44444444444444444444444444444444";
        var expiredState = new CrashRecoveryRestartState(
            pendingToken,
            Now
                - CrashRecoveryRestartPolicy.PendingTokenLifetime
                - TimeSpan.FromSeconds(1),
            null);
        var freshState = expiredState with
        {
            PendingRegisteredAtUtc = Now - TimeSpan.FromMinutes(1),
        };

        var expired = CrashRecoveryRestartPolicy.EvaluateStartup(
            [$"{CrashRecoveryRestartPolicy.RecoveryArgumentPrefix}{pendingToken}"],
            expiredState,
            Now);
        var mismatched = CrashRecoveryRestartPolicy.EvaluateStartup(
            [$"{CrashRecoveryRestartPolicy.RecoveryArgumentPrefix}{suppliedToken}"],
            freshState,
            Now);

        Assert.AreEqual(
            CrashRecoveryStartupDisposition.RecoveryArgumentInvalid,
            expired.Disposition);
        Assert.AreEqual(
            CrashRecoveryStartupDisposition.RecoveryArgumentInvalid,
            mismatched.Disposition);
    }

    [TestMethod]
    public void RegistrationUsesOneTimeTokenWithoutChangingWindow()
    {
        const string token = "55555555555555555555555555555555";
        var lastRecovery = Now - TimeSpan.FromMinutes(11);
        var state = new CrashRecoveryRestartState(null, null, lastRecovery);

        var prepared = CrashRecoveryRestartPolicy.PrepareRegistration(
            state,
            Now,
            token);

        Assert.AreEqual(token, prepared.PendingToken);
        Assert.AreEqual(Now, prepared.PendingRegisteredAtUtc);
        Assert.AreEqual(lastRecovery, prepared.LastRecoveryStartedAtUtc);
        Assert.AreEqual(
            TimeSpan.Zero,
            CrashRecoveryRestartPolicy.RegistrationDelay(prepared, Now));
    }
}
