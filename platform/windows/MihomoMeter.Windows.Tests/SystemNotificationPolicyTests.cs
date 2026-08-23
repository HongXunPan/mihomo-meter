using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class SystemNotificationPolicyTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.FromUnixTimeSeconds(1_800_000_000);
    private static readonly Guid SubscriptionId = Guid.Parse(
        "11111111-1111-1111-1111-111111111111");
    private static readonly Guid CycleId = Guid.Parse(
        "22222222-2222-2222-2222-222222222222");

    [TestMethod]
    public void CreatesThreeQuotaDeliveriesAtConfirmedThresholds()
    {
        var analysis = MakeAnalysis(
            usedBytes: 900,
            expireAt: Now + TimeSpan.FromDays(3),
            estimatedAt: Now + TimeSpan.FromMinutes(1));

        var deliveries = QuotaSystemNotificationPolicy.Deliveries([analysis], Now);

        Assert.AreEqual(3, deliveries.Count);
        Assert.IsTrue(deliveries.All(item =>
            item.Target == AppActivationTarget.SubscriptionQuota));
        Assert.AreEqual(3, deliveries.Select(item => item.DeduplicationKey).Distinct().Count());
    }

    [TestMethod]
    public void ExcludesUnconfirmedStaleAndRecoveredConditions()
    {
        var unconfirmed = MakeAnalysis(usedBytes: 900, isConfirmed: false);
        var stale = MakeAnalysis(
            usedBytes: 900,
            observedAt: Now - QuotaSystemNotificationPolicy.MaximumSnapshotAge
                - TimeSpan.FromSeconds(1));
        var recovered = MakeAnalysis(
            usedBytes: 899,
            expireAt: Now + QuotaSystemNotificationPolicy.UpcomingInterval
                + TimeSpan.FromSeconds(1),
            estimatedAt: Now);

        var deliveries = QuotaSystemNotificationPolicy.Deliveries(
            [unconfirmed, stale, recovered],
            Now);

        Assert.AreEqual(0, deliveries.Count);
    }

    [TestMethod]
    public void SustainedDisconnectionRequiresTenMinutes()
    {
        var disconnectedSince = Now - TimeSpan.FromMinutes(10);

        Assert.IsFalse(ConnectionSystemNotificationPolicy.ShouldNotify(
            disconnectedSince,
            Now - TimeSpan.FromSeconds(1)));
        Assert.IsTrue(ConnectionSystemNotificationPolicy.ShouldNotify(disconnectedSince, Now));
        Assert.IsFalse(ConnectionSystemNotificationPolicy.ShouldNotify(null, Now));
    }

    [TestMethod]
    public void ActivationTargetsOnlyAcceptFixedValues()
    {
        Assert.IsTrue(AppActivationTargetContract.TryParse(
            "subscriptionQuota",
            out var target));
        Assert.AreEqual(AppActivationTarget.SubscriptionQuota, target);
        Assert.IsFalse(AppActivationTargetContract.TryParse(
            "https://example.com",
            out _));
    }

    [TestMethod]
    public void DeepLinksOnlyAcceptFixedParameterlessUrls()
    {
        Assert.IsTrue(AppDeepLink.TryParse(
            new Uri(AppDeepLink.StatisticsUrl),
            out var target));
        Assert.AreEqual(AppActivationTarget.Statistics, target);
        Assert.IsTrue(AppDeepLink.TryParse(
            new Uri(AppDeepLink.SubscriptionQuotaUrl),
            out target));
        Assert.AreEqual(AppActivationTarget.SubscriptionQuota, target);
        Assert.IsTrue(AppDeepLink.TryParse(
            new Uri(AppDeepLink.ConnectionSettingsUrl),
            out target));
        Assert.AreEqual(AppActivationTarget.ControllerSettings, target);

        var rejectedValues = new[]
        {
            "mihomo-meter://statistics/",
            "mihomo-meter://statistics?range=day",
            "mihomo-meter://statistics#detail",
            "mihomo-meter://unknown",
            "https://example.com",
        };
        foreach (var value in rejectedValues)
        {
            Assert.IsFalse(AppDeepLink.TryParse(new Uri(value), out target), value);
            Assert.AreEqual(AppActivationTarget.MainWindow, target, value);
        }
    }

    private static SubscriptionQuotaAnalysis MakeAnalysis(
        ulong usedBytes,
        DateTimeOffset? observedAt = null,
        DateTimeOffset? expireAt = null,
        DateTimeOffset? estimatedAt = null,
        bool isConfirmed = true)
    {
        var timestamp = observedAt ?? Now;
        var subscription = new TrackedSubscription(
            SubscriptionId,
            "测试订阅",
            SubscriptionIdentityMode.RuntimeSingle,
            null,
            null,
            null,
            SubscriptionTrackingStatus.Active,
            timestamp - TimeSpan.FromDays(1),
            timestamp);
        var traffic = new QuotaTraffic(usedBytes / 2, usedBytes - usedBytes / 2, 1_000);
        var snapshot = new SubscriptionQuotaSnapshot(
            Guid.NewGuid(),
            SubscriptionId,
            CycleId,
            timestamp,
            null,
            QuotaObservationSource.MihomoRuntime,
            traffic,
            expireAt);
        var cycle = new QuotaCycle(
            CycleId,
            SubscriptionId,
            timestamp - TimeSpan.FromDays(1),
            null,
            QuotaCycleStartReason.Initial,
            isConfirmed);
        var forecast = new QuotaDepletionForecast(
            estimatedAt,
            estimatedAt is null
                ? QuotaForecastUnavailableReason.InsufficientSamples
                : QuotaForecastUnavailableReason.None);
        return new SubscriptionQuotaAnalysis(
            subscription,
            snapshot,
            cycle,
            [],
            null,
            new Dictionary<QuotaTrendWindow, QuotaTrend>(),
            forecast);
    }
}
