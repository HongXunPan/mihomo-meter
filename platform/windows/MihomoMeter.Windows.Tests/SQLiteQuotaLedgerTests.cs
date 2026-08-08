using Microsoft.Data.Sqlite;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Quota;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class SQLiteQuotaLedgerTests
{
    private string _testDirectory = string.Empty;
    private string _databasePath = string.Empty;

    [TestInitialize]
    public void SetUp()
    {
        WindowsSqliteTestProvider.Initialize();
        _testDirectory = Path.Combine(
            AppContext.BaseDirectory,
            "QuotaLedgerData",
            Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_testDirectory);
        _databasePath = Path.Combine(_testDirectory, "quota.sqlite3");
    }

    [TestCleanup]
    public void TearDown()
    {
        if (Directory.Exists(_testDirectory))
        {
            Directory.Delete(_testDirectory, true);
        }
    }

    [TestMethod]
    public async Task PersistsSnapshotsCyclesEventsAndConfirmation()
    {
        var now = new DateTimeOffset(2026, 8, 8, 0, 0, 0, TimeSpan.Zero);
        var subscription = ProfileSubscription(now);
        await using (var ledger = new SQLiteQuotaLedger(_databasePath))
        {
            await ledger.PrepareAsync(now, CancellationToken.None);
            await ledger.UpsertSubscriptionAsync(subscription, now, CancellationToken.None);
            var initial = await Record(
                ledger,
                subscription,
                now.AddMinutes(1),
                new QuotaTraffic(40, 60, 1_000),
                null);
            Assert.IsTrue(initial.Subscriptions.Single().CurrentCycle!.IsUserConfirmed);

            var changed = await Record(
                ledger,
                subscription,
                now.AddMinutes(2),
                new QuotaTraffic(80, 120, 1_200),
                now.AddDays(30));
            CollectionAssert.AreEquivalent(
                new[] { QuotaEventKind.TotalIncreased, QuotaEventKind.ExpirationChanged },
                changed.Subscriptions.Single().RecentEvents.Select(item => item.Kind).ToArray());

            var reset = await Record(
                ledger,
                subscription,
                now.AddMinutes(3),
                new QuotaTraffic(20, 30, 1_200),
                now.AddDays(30));
            var analysis = reset.Subscriptions.Single();
            Assert.AreEqual(QuotaCycleStartReason.UsageReset, analysis.CurrentCycle!.StartReason);
            Assert.IsFalse(analysis.CurrentCycle!.IsUserConfirmed);
            Assert.IsTrue(analysis.RecentEvents.Any(item =>
                item.Kind == QuotaEventKind.UsageReset && !item.IsUserConfirmed));

            var confirmed = await ledger.ConfirmCycleAsync(
                analysis.CurrentCycle!.Id,
                now.AddMinutes(4),
                CancellationToken.None);
            Assert.IsTrue(confirmed.Subscriptions.Single().CurrentCycle!.IsUserConfirmed);
            Assert.IsTrue(confirmed.Subscriptions.Single().RecentEvents
                .Where(item => item.Kind == QuotaEventKind.UsageReset)
                .All(item => item.IsUserConfirmed));
        }

        await using var reopened = new SQLiteQuotaLedger(_databasePath);
        var restored = await reopened.PrepareAsync(now.AddMinutes(5), CancellationToken.None);

        Assert.AreEqual(subscription.Id, restored.Subscriptions.Single().Subscription.Id);
        Assert.AreEqual(50UL, restored.Subscriptions.Single().LatestSnapshot!.Traffic.UsedBytes);
        Assert.IsTrue(restored.Subscriptions.Single().CurrentCycle!.IsUserConfirmed);
    }

    [TestMethod]
    public async Task PersistsProfileQueryStateWithoutRawUrl()
    {
        var now = new DateTimeOffset(2026, 8, 8, 0, 0, 0, TimeSpan.Zero);
        var subscription = ProfileSubscription(now);
        await using var ledger = new SQLiteQuotaLedger(_databasePath);
        await ledger.PrepareAsync(now, CancellationToken.None);
        await ledger.UpsertSubscriptionAsync(subscription, now, CancellationToken.None);
        var state = new ProfileQuotaQueryState(
            subscription.Id,
            now,
            now.AddHours(6),
            subscription.UrlFingerprint,
            0,
            null,
            0,
            null);

        var snapshot = await ledger.SaveQueryStateAsync(
            state,
            now,
            CancellationToken.None);

        Assert.AreEqual(state, snapshot.Subscriptions.Single().QueryState);
        using var connection = OpenDatabase();
        var schema = string.Join(
            '\n',
            ReadStrings(connection, "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL"));
        Assert.IsTrue(schema.Contains("url_fingerprint", StringComparison.Ordinal));
        Assert.IsFalse(schema.Contains("subscription_url", StringComparison.Ordinal));
        Assert.IsFalse(schema.Contains("controller_secret", StringComparison.Ordinal));
        Assert.IsFalse(schema.Contains("provider_key", StringComparison.Ordinal));
    }

    [TestMethod]
    public async Task ResetClearsOnlyQuotaLedgerAndPreservesSiblingTrafficFile()
    {
        var now = new DateTimeOffset(2026, 8, 8, 0, 0, 0, TimeSpan.Zero);
        var trafficPath = Path.Combine(_testDirectory, "traffic.sqlite3");
        await File.WriteAllTextAsync(trafficPath, "traffic-ledger-marker");
        await using var ledger = new SQLiteQuotaLedger(_databasePath);
        await ledger.PrepareAsync(now, CancellationToken.None);
        var subscription = ProfileSubscription(now);
        await ledger.UpsertSubscriptionAsync(subscription, now, CancellationToken.None);
        await Record(
            ledger,
            subscription,
            now.AddMinutes(1),
            new QuotaTraffic(1, 2, 100),
            null);

        var reset = await ledger.ResetAsync(now.AddMinutes(2), CancellationToken.None);

        Assert.AreEqual(0, reset.Subscriptions.Count);
        Assert.AreEqual("traffic-ledger-marker", await File.ReadAllTextAsync(trafficPath));
    }

    [TestMethod]
    public async Task RejectsNewerSchemaAndReleasesDatabaseHandle()
    {
        using (var connection = OpenDatabase())
        {
            using var command = connection.CreateCommand();
            command.CommandText = "PRAGMA user_version = 99";
            command.ExecuteNonQuery();
        }

        await using (var ledger = new SQLiteQuotaLedger(_databasePath))
        {
            await Assert.ThrowsExactlyAsync<QuotaLedgerException>(() =>
                ledger.PrepareAsync(DateTimeOffset.UtcNow, CancellationToken.None));
        }

        File.Delete(_databasePath);
        Assert.IsFalse(File.Exists(_databasePath));
    }

    [TestMethod]
    public async Task RejectsObservationSourceThatDoesNotMatchIdentity()
    {
        var now = DateTimeOffset.UtcNow;
        var subscription = ProfileSubscription(now);
        await using var ledger = new SQLiteQuotaLedger(_databasePath);
        await ledger.PrepareAsync(now, CancellationToken.None);
        await ledger.UpsertSubscriptionAsync(subscription, now, CancellationToken.None);

        await Assert.ThrowsExactlyAsync<QuotaLedgerException>(() => ledger.RecordAsync(
            new QuotaObservation(
                subscription.Id,
                now.AddSeconds(1),
                null,
                QuotaObservationSource.MihomoRuntime,
                new QuotaTraffic(1, 2, 100),
                null),
            now.AddSeconds(1),
            CancellationToken.None));
    }

    [TestMethod]
    public async Task UidChangeRequiresNewIdentityInsteadOfReusingHistory()
    {
        var now = DateTimeOffset.UtcNow;
        var original = ProfileSubscription(now);
        await using var ledger = new SQLiteQuotaLedger(_databasePath);
        await ledger.PrepareAsync(now, CancellationToken.None);
        await ledger.UpsertSubscriptionAsync(original, now, CancellationToken.None);
        var changedUid = new TrackedSubscription(
            original.Id,
            original.Name,
            original.IdentityMode,
            "different-uid",
            original.UrlFingerprint,
            original.RefreshIntervalMinutes,
            original.Status,
            original.CreatedAt,
            now.AddSeconds(1));

        await Assert.ThrowsExactlyAsync<QuotaLedgerException>(() =>
            ledger.UpsertSubscriptionAsync(
                changedUid,
                now.AddSeconds(1),
                CancellationToken.None));

        var imported = new TrackedSubscription(
            Guid.NewGuid(),
            "重新导入",
            SubscriptionIdentityMode.ClashProfile,
            "different-uid",
            new string('b', 64),
            360,
            SubscriptionTrackingStatus.Active,
            now.AddSeconds(2),
            now.AddSeconds(2));
        var snapshot = await ledger.UpsertSubscriptionAsync(
            imported,
            now.AddSeconds(2),
            CancellationToken.None);

        Assert.AreEqual(2, snapshot.Subscriptions.Count);
        Assert.IsTrue(snapshot.Subscriptions.Any(item => item.Subscription.Id == original.Id));
        Assert.IsTrue(snapshot.Subscriptions.Any(item => item.Subscription.Id == imported.Id));
    }

    private static Task<QuotaLedgerSnapshot> Record(
        SQLiteQuotaLedger ledger,
        TrackedSubscription subscription,
        DateTimeOffset date,
        QuotaTraffic traffic,
        DateTimeOffset? expireAt)
    {
        return ledger.RecordAsync(
            new QuotaObservation(
                subscription.Id,
                date,
                null,
                QuotaObservationSource.MeterActiveQuery,
                traffic,
                expireAt),
            date,
            CancellationToken.None);
    }

    private static TrackedSubscription ProfileSubscription(DateTimeOffset now)
    {
        return new TrackedSubscription(
            Guid.NewGuid(),
            "主订阅",
            SubscriptionIdentityMode.ClashProfile,
            "profile-main",
            new string('a', 64),
            360,
            SubscriptionTrackingStatus.Active,
            now,
            now);
    }

    private SqliteConnection OpenDatabase()
    {
        var connection = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = _databasePath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Pooling = false,
        }.ToString());
        connection.Open();
        return connection;
    }

    private static IReadOnlyList<string> ReadStrings(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        using var reader = command.ExecuteReader();
        var values = new List<string>();
        while (reader.Read())
        {
            values.Add(reader.GetString(0));
        }

        return values;
    }
}
