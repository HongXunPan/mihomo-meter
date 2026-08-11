using System.Text;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class QuotaDomainTests
{
    [TestMethod]
    public void TrafficRejectsZeroTotalAndIntegerOverflow()
    {
        Assert.ThrowsExactly<QuotaDomainException>(() => new QuotaTraffic(1, 2, 0));
        Assert.ThrowsExactly<QuotaDomainException>(() => new QuotaTraffic(
            checked((ulong)long.MaxValue),
            1,
            checked((ulong)long.MaxValue)));
    }

    [TestMethod]
    public void SubscriptionHeaderAcceptsDecimalsAndCompatibleFieldOrder()
    {
        var result = SubscriptionUserInfoParser.Parse(
            "total=1000; download=200.9; upload=100.1; expire=1700000000");

        Assert.AreEqual(100UL, result.Traffic.UploadBytes);
        Assert.AreEqual(200UL, result.Traffic.DownloadBytes);
        Assert.AreEqual(700UL, result.Traffic.RemainingBytes);
        Assert.AreEqual(
            DateTimeOffset.FromUnixTimeSeconds(1_700_000_000),
            result.ExpireAt);
    }

    [TestMethod]
    public void SubscriptionHeaderRejectsMissingOrOverflowingQuota()
    {
        Assert.ThrowsExactly<ActiveQuotaQueryException>(() =>
            SubscriptionUserInfoParser.Parse("upload=1; download=2"));
        Assert.ThrowsExactly<ActiveQuotaQueryException>(() =>
            SubscriptionUserInfoParser.Parse(
                "upload=9223372036854775807; download=1; total=9223372036854775807"));
    }

    [TestMethod]
    public void RuntimeSelectionKeepsOnlyOneValidUppercaseCandidate()
    {
        var json = Encoding.UTF8.GetBytes(
            """
            {
              "providers": {
                "good": {
                  "updatedAt": "2026-08-08T00:00:00Z",
                  "subscriptionInfo": {
                    "Upload": 10, "Download": 20, "Total": 100, "Expire": 1800000000
                  }
                },
                "negative": {
                  "subscriptionInfo": {"upload": -1, "download": 2, "total": 100}
                },
                "incomplete": {
                  "subscriptionInfo": {"upload": 1, "download": 2}
                }
              }
            }
            """);

        var selection = MihomoJsonDecoder
            .Decode<MihomoProxyProvidersResponse>(json)
            .ToRuntimeSelection();

        Assert.AreEqual(RuntimeQuotaCandidateSelectionKind.Single, selection.Kind);
        Assert.AreEqual(1, selection.CandidateCount);
        Assert.AreEqual("good", selection.Candidate?.SourceKey);
        Assert.AreEqual(70UL, selection.Candidate!.Traffic.RemainingBytes);
    }

    [TestMethod]
    public void RuntimeSelectionDoesNotGuessAmongMultipleCandidates()
    {
        var first = Candidate("one", 1);
        var second = Candidate("two", 2);

        var selection = RuntimeQuotaCandidateSelection.From([first, second]);

        Assert.AreEqual(RuntimeQuotaCandidateSelectionKind.Multiple, selection.Kind);
        Assert.AreEqual(2, selection.CandidateCount);
        Assert.IsNull(selection.Candidate);

        var empty = RuntimeQuotaCandidateSelection.From([]);
        Assert.AreEqual(RuntimeQuotaCandidateSelectionKind.None, empty.Kind);
        Assert.AreEqual(0, empty.CandidateCount);
    }

    [TestMethod]
    public void RuntimeConfigurationPrefersMixedAndSanitizesUserAgent()
    {
        var response = new MihomoQuotaConfigurationResponse
        {
            MixedPort = 7890,
            HttpPort = 7891,
            SocksPort = 7892,
            GlobalUserAgent = "unsafe\r\nvalue",
        };

        var configuration = response.ToRuntimeConfiguration();

        Assert.AreEqual(MihomoLocalProxyKind.Mixed, configuration.Proxy?.Kind);
        Assert.AreEqual(new Uri("http://127.0.0.1:7890"), configuration.Proxy?.ProxyUri);
        Assert.AreEqual("clash.meta", configuration.UserAgent);
        Assert.IsFalse(configuration.UsesConfiguredUserAgent);
    }

    [TestMethod]
    public void TrendUsesRealPointsAndBreaksAtCycleOrCounterRegression()
    {
        var now = new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);
        var subscription = Guid.NewGuid();
        var firstCycle = Guid.NewGuid();
        var secondCycle = Guid.NewGuid();
        var snapshots = new[]
        {
            Snapshot(subscription, firstCycle, now.AddHours(-10), 10, 20),
            Snapshot(subscription, firstCycle, now.AddHours(-8), 15, 25),
            Snapshot(subscription, firstCycle, now.AddHours(-6), 14, 28),
            Snapshot(subscription, secondCycle, now.AddHours(-4), 2, 3),
            Snapshot(subscription, secondCycle, now.AddHours(-2), 4, 8),
        };

        var trend = QuotaTrendEngine.Calculate(snapshots, QuotaTrendWindow.Day, now);

        Assert.AreEqual(3, trend.Segments.Count);
        Assert.AreEqual(7UL, trend.RangeUsage.UploadBytes);
        Assert.AreEqual(10UL, trend.RangeUsage.DownloadBytes);
        CollectionAssert.AreEqual(
            snapshots.Select(item => item.Id).ToArray(),
            QuotaTrendEngine.Sample(trend.Segments, 120).Select(item => item.Id).ToArray());
    }

    [TestMethod]
    public void TrendWindowsAndSamplingPreserveRealBoundaryPoints()
    {
        var now = new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);
        Assert.AreEqual(now.AddHours(-24), QuotaTrendEngine.StartDate(QuotaTrendWindow.Day, now));
        Assert.AreEqual(now.AddDays(-7), QuotaTrendEngine.StartDate(QuotaTrendWindow.Week, now));
        Assert.AreEqual(now.AddDays(-30), QuotaTrendEngine.StartDate(QuotaTrendWindow.Month, now));
        Assert.AreEqual(now.AddMonths(-12), QuotaTrendEngine.StartDate(QuotaTrendWindow.Year, now));

        var subscription = Guid.NewGuid();
        var cycle = Guid.NewGuid();
        var snapshots = Enumerable.Range(0, 200)
            .Select(index => Snapshot(
                subscription,
                cycle,
                now.AddMinutes(index - 199),
                (ulong)index,
                (ulong)(index * 2)))
            .ToArray();
        var trend = QuotaTrendEngine.Calculate(snapshots, QuotaTrendWindow.Day, now);
        var sampled = QuotaTrendEngine.Sample(trend.Segments, 20);
        var sourceIds = snapshots.Select(item => item.Id).ToHashSet();

        Assert.IsTrue(sampled.Count <= 20);
        Assert.AreEqual(snapshots[0].Id, sampled[0].Id);
        Assert.AreEqual(snapshots[^1].Id, sampled[^1].Id);
        Assert.IsTrue(sampled.All(item => sourceIds.Contains(item.Id)));
    }

    [TestMethod]
    public void TrendTargetPointCountFollowsAvailableWidthWithinMacBounds()
    {
        Assert.AreEqual(2, QuotaTrendEngine.TargetPointCount(0));
        Assert.AreEqual(2, QuotaTrendEngine.TargetPointCount(79));
        Assert.AreEqual(3, QuotaTrendEngine.TargetPointCount(120));
        Assert.AreEqual(30, QuotaTrendEngine.TargetPointCount(1_200));
        Assert.AreEqual(30, QuotaTrendEngine.TargetPointCount(10_000));
    }

    [TestMethod]
    public void ForecastRequiresConfirmedFreshCycleAndSixHourSpan()
    {
        var now = new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);
        var subscription = Guid.NewGuid();
        var cycleId = Guid.NewGuid();
        var snapshots = new[]
        {
            Snapshot(subscription, cycleId, now.AddHours(-7), 100, 100, total: 1_000),
            Snapshot(subscription, cycleId, now, 170, 170, total: 1_000),
        };
        var unconfirmed = new QuotaCycle(
            cycleId,
            subscription,
            now.AddHours(-7),
            null,
            QuotaCycleStartReason.UsageReset,
            false);

        var unavailable = QuotaTrendEngine.Forecast(
            snapshots,
            unconfirmed,
            now,
            TimeSpan.FromDays(1));
        var available = QuotaTrendEngine.Forecast(
            snapshots,
            unconfirmed with { IsUserConfirmed = true },
            now,
            TimeSpan.FromDays(1));

        Assert.AreEqual(QuotaForecastUnavailableReason.UnconfirmedCycle, unavailable.UnavailableReason);
        Assert.IsTrue(available.IsAvailable);
        Assert.IsTrue(available.EstimatedAt > now);
    }

    [TestMethod]
    public void ScheduleHonorsUrlChangeCooldownAndRetryLimit()
    {
        var now = new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);
        var subscription = ProfileSubscription(now, "new-fingerprint");
        var policy = new ProfileQuotaSchedulePolicy();
        var previous = ProfileQuotaQueryState.Empty(subscription.Id) with
        {
            LastAttemptAt = now,
            NextAttemptAt = now.AddHours(6),
            LastQueriedUrlFingerprint = "old-fingerprint",
            LastFailureCategory = "missing_header",
        };

        Assert.AreEqual(now, policy.DueDate(subscription, previous, now));
        Assert.IsFalse(policy.CanRefreshManually(previous, now.AddSeconds(30)));
        Assert.IsTrue(policy.CanRefreshManually(
            previous with { LastFailureCategory = "network" },
            now));

        var state = previous with
        {
            LastQueriedUrlFingerprint = subscription.UrlFingerprint,
            ConsecutiveFailures = 1,
            RetryDayStart = new DateTimeOffset(now.Year, now.Month, now.Day, 0, 0, 0, now.Offset),
            AutomaticRetryCount = 2,
        };
        var failed = policy.Failure(
            subscription,
            state,
            ProfileQuotaQueryTrigger.Automatic,
            now,
            TimeSpan.Zero,
            "network");

        Assert.AreEqual(3, failed.AutomaticRetryCount);
        Assert.AreEqual(0, failed.ConsecutiveFailures);
        Assert.AreEqual(now.AddHours(6), failed.NextAttemptAt);
    }

    private static RuntimeQuotaCandidate Candidate(string key, ulong value)
    {
        return new RuntimeQuotaCandidate(
            key,
            null,
            new QuotaTraffic(value, value, 100),
            null);
    }

    private static SubscriptionQuotaSnapshot Snapshot(
        Guid subscription,
        Guid cycle,
        DateTimeOffset date,
        ulong upload,
        ulong download,
        ulong total = 10_000)
    {
        return new SubscriptionQuotaSnapshot(
            Guid.NewGuid(),
            subscription,
            cycle,
            date,
            null,
            QuotaObservationSource.MeterActiveQuery,
            new QuotaTraffic(upload, download, total),
            null);
    }

    private static TrackedSubscription ProfileSubscription(
        DateTimeOffset now,
        string fingerprint)
    {
        return new TrackedSubscription(
            Guid.NewGuid(),
            "订阅",
            SubscriptionIdentityMode.ClashProfile,
            "uid",
            fingerprint,
            360,
            SubscriptionTrackingStatus.Active,
            now,
            now);
    }
}
