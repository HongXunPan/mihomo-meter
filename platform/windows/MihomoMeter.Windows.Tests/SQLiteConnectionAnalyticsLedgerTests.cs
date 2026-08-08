using Microsoft.Data.Sqlite;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.ConnectionAnalytics;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class SQLiteConnectionAnalyticsLedgerTests
{
    private string _testDirectory = string.Empty;
    private string _databasePath = string.Empty;

    [TestInitialize]
    public void SetUp()
    {
        _testDirectory = Path.Combine(
            AppContext.BaseDirectory,
            "TestData",
            Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_testDirectory);
        _databasePath = Path.Combine(_testDirectory, "connection-analytics.sqlite3");
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
    public async Task HistoryIsDisabledByDefaultAndIgnoresAggregates()
    {
        var now = new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);
        await using var ledger = new SQLiteConnectionAnalyticsLedger(_databasePath);

        var prepared = await ledger.PrepareAsync(TimeZoneInfo.Utc, now, CancellationToken.None);
        var recorded = await ledger.RecordAsync(
            [Aggregate("2026-08-08", "Browser", "example.test", 10, 20)],
            5_000,
            TimeZoneInfo.Utc,
            now,
            CancellationToken.None);

        Assert.IsFalse(prepared.IsHistoryEnabled);
        Assert.AreEqual(30, prepared.RecentDays.Count);
        Assert.AreEqual(TrafficBytes.Zero, recorded.RecentDays[^1].Bytes);
        Assert.AreEqual(
            0,
            (await ledger.RecordsAsync("2026-08-08", CancellationToken.None)).Count);
    }

    [TestMethod]
    public async Task PersistsEnabledSettingAndDailyAggregatesAcrossRestart()
    {
        var now = new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);
        await using (var ledger = new SQLiteConnectionAnalyticsLedger(_databasePath))
        {
            _ = await ledger.PrepareAsync(TimeZoneInfo.Utc, now, CancellationToken.None);
            _ = await ledger.SetHistoryEnabledAsync(
                true,
                TimeZoneInfo.Utc,
                now,
                CancellationToken.None);
            _ = await ledger.RecordAsync(
                [
                    Aggregate("2026-08-08", "Browser", "example.test", 10, 20),
                    Aggregate("2026-08-08", "Browser", "example.test", 5, 7),
                ],
                5_000,
                TimeZoneInfo.Utc,
                now,
                CancellationToken.None);
        }

        await using var reopened = new SQLiteConnectionAnalyticsLedger(_databasePath);
        var snapshot = await reopened.PrepareAsync(
            TimeZoneInfo.Utc,
            now,
            CancellationToken.None);
        var records = await reopened.RecordsAsync("2026-08-08", CancellationToken.None);

        Assert.IsTrue(snapshot.IsHistoryEnabled);
        Assert.AreEqual(new TrafficBytes(15, 27), snapshot.RecentDays[^1].Bytes);
        Assert.AreEqual(1, records.Count);
        Assert.AreEqual(new TrafficBytes(15, 27), records[0].Bytes);
    }

    [TestMethod]
    public async Task CalculatesMetadataCoverageFromStoredBytes()
    {
        var now = new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);
        await using var ledger = await EnabledLedgerAsync(now);

        var snapshot = await ledger.RecordAsync(
            [
                Aggregate("2026-08-08", "Browser", "known.test", 10, 10),
                Aggregate(
                    "2026-08-08",
                    ConnectionAttributionLabel.UnknownApplication,
                    "host-only.test",
                    5,
                    5),
                Aggregate(
                    "2026-08-08",
                    "AppOnly",
                    ConnectionAttributionLabel.UnknownHostname,
                    2,
                    3),
            ],
            5_000,
            TimeZoneInfo.Utc,
            now,
            CancellationToken.None);

        var coverage = snapshot.RecentDays[^1].Coverage;
        Assert.AreEqual(new TrafficBytes(17, 18), coverage.Total);
        Assert.AreEqual(new TrafficBytes(15, 15), coverage.HostnameAttributed);
        Assert.AreEqual(new TrafficBytes(12, 13), coverage.ApplicationAttributed);
        Assert.AreEqual(new TrafficBytes(10, 10), coverage.FullyAttributed);
    }

    [TestMethod]
    public async Task ReservesOneDailySlotForOverflowAggregate()
    {
        var now = new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);
        await using var ledger = await EnabledLedgerAsync(now);

        _ = await ledger.RecordAsync(
            Enumerable.Range(1, 5)
                .Select(index => Aggregate(
                    "2026-08-08",
                    $"App {index}",
                    $"host-{index}.test",
                    (ulong)index,
                    (ulong)index))
                .ToArray(),
            3,
            TimeZoneInfo.Utc,
            now,
            CancellationToken.None);
        var records = await ledger.RecordsAsync("2026-08-08", CancellationToken.None);

        Assert.AreEqual(3, records.Count);
        var overflow = records.Single(record =>
            record.ApplicationName == ConnectionAttributionLabel.Overflow
            && record.Hostname == ConnectionAttributionLabel.Overflow);
        Assert.AreEqual(new TrafficBytes(12, 12), overflow.Bytes);
    }

    [TestMethod]
    public async Task PrunesArchivedDaysOutsideRecentThirtyDayWindow()
    {
        var oldNow = new DateTimeOffset(2026, 6, 1, 12, 0, 0, TimeSpan.Zero);
        await using var ledger = await EnabledLedgerAsync(oldNow);
        _ = await ledger.RecordAsync(
            [Aggregate("2026-06-01", "Old", "old.test", 1, 2)],
            5_000,
            TimeZoneInfo.Utc,
            oldNow,
            CancellationToken.None);

        var future = oldNow.AddDays(40);
        _ = await ledger.PrepareAsync(TimeZoneInfo.Utc, future, CancellationToken.None);

        Assert.AreEqual(
            0,
            (await ledger.RecordsAsync("2026-06-01", CancellationToken.None)).Count);
    }

    [TestMethod]
    public async Task TrendUsesExactFiltersAndFillsThirtyLocalDays()
    {
        var now = new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);
        await using var ledger = await EnabledLedgerAsync(now);
        _ = await ledger.RecordAsync(
            [
                Aggregate("2026-08-07", "Browser", "a.test", 10, 20),
                Aggregate("2026-08-08", "Browser", "a.test", 20, 30),
                Aggregate("2026-08-08", "Browser", "b.test", 100, 100),
                Aggregate("2026-08-08", "Other", "a.test", 200, 200),
            ],
            5_000,
            TimeZoneInfo.Utc,
            now,
            CancellationToken.None);

        var trend = await ledger.TrendAsync(
            new ConnectionAnalyticsTrendQuery("Browser", "a.test"),
            TimeZoneInfo.Utc,
            now,
            CancellationToken.None);

        Assert.AreEqual(30, trend.Points.Count);
        Assert.AreEqual(new TrafficBytes(30, 50), trend.TotalBytes);
        Assert.AreEqual(2, trend.ActiveDayCount);
        Assert.AreEqual((ulong)40, trend.ActiveDailyAverageBytes);
        Assert.AreEqual("2026-08-08", trend.PeakPoint?.LocalDay);
        Assert.AreEqual("2026-08-08", trend.DefaultSelectedLocalDay);
    }

    [TestMethod]
    public async Task ClearHistoryRetainsEnabledPreference()
    {
        var now = new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);
        await using var ledger = await EnabledLedgerAsync(now);
        _ = await ledger.RecordAsync(
            [Aggregate("2026-08-08", "Browser", "a.test", 10, 20)],
            5_000,
            TimeZoneInfo.Utc,
            now,
            CancellationToken.None);

        var cleared = await ledger.ClearHistoryAsync(
            TimeZoneInfo.Utc,
            now,
            CancellationToken.None);

        Assert.IsTrue(cleared.IsHistoryEnabled);
        Assert.IsTrue(cleared.RecentDays.All(day => day.Bytes == TrafficBytes.Zero));
    }

    [TestMethod]
    public async Task RejectsDatabaseSchemaNewerThanApplication()
    {
        using (var connection = new SqliteConnection(
            $"Data Source={_databasePath};Pooling=False"))
        {
            connection.Open();
            using var command = connection.CreateCommand();
            command.CommandText = "PRAGMA user_version = 2";
            command.ExecuteNonQuery();
        }

        await using var ledger = new SQLiteConnectionAnalyticsLedger(_databasePath);
        await Assert.ThrowsExactlyAsync<ConnectionAnalyticsException>(() => ledger.PrepareAsync(
            TimeZoneInfo.Utc,
            DateTimeOffset.UtcNow,
            CancellationToken.None));
    }

    [TestMethod]
    public async Task SchemaContainsOnlyApprovedDailyAggregateFields()
    {
        await using (var ledger = new SQLiteConnectionAnalyticsLedger(_databasePath))
        {
            _ = await ledger.PrepareAsync(
                TimeZoneInfo.Utc,
                _nowForSchema,
                CancellationToken.None);
        }

        using var connection = new SqliteConnection($"Data Source={_databasePath};Pooling=False");
        connection.Open();
        CollectionAssert.AreEqual(
            new[] { "id", "history_enabled" },
            ReadColumns(connection, "connection_analytics_settings"));
        CollectionAssert.AreEqual(
            new[]
            {
                "local_day",
                "application_name",
                "hostname",
                "upload_bytes",
                "download_bytes",
            },
            ReadColumns(connection, "connection_daily_attribution"));
    }

    private async Task<SQLiteConnectionAnalyticsLedger> EnabledLedgerAsync(DateTimeOffset now)
    {
        var ledger = new SQLiteConnectionAnalyticsLedger(_databasePath);
        _ = await ledger.PrepareAsync(TimeZoneInfo.Utc, now, CancellationToken.None);
        _ = await ledger.SetHistoryEnabledAsync(
            true,
            TimeZoneInfo.Utc,
            now,
            CancellationToken.None);
        return ledger;
    }

    private static ConnectionAttributionAggregate Aggregate(
        string localDay,
        string applicationName,
        string hostname,
        ulong upload,
        ulong download)
    {
        return new ConnectionAttributionAggregate(
            new ConnectionAttributionStorageKey(localDay, applicationName, hostname),
            new TrafficBytes(upload, download));
    }

    private static readonly DateTimeOffset _nowForSchema =
        new(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);

    private static string[] ReadColumns(SqliteConnection connection, string table)
    {
        using var command = connection.CreateCommand();
        command.CommandText = $"PRAGMA table_info({table})";
        using var reader = command.ExecuteReader();
        var names = new List<string>();
        while (reader.Read())
        {
            names.Add(reader.GetString(1));
        }
        return names.ToArray();
    }
}
