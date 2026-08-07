using Microsoft.Data.Sqlite;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Statistics;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class SQLiteTrafficLedgerTests
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
        _databasePath = Path.Combine(_testDirectory, "traffic.sqlite3");
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
    public async Task PersistsCategorizedTotalsAcrossApplicationRestart()
    {
        var startedAt = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);
        await using (var ledger = new SQLiteTrafficLedger(_databasePath))
        {
            await ledger.PrepareAsync(TimeZoneInfo.Utc, startedAt, CancellationToken.None);
            await ledger.BeginMonitoringAsync(
                "v1.19.29",
                TimeZoneInfo.Utc,
                startedAt,
                CancellationToken.None);
            await ledger.RecordAsync(
                Baseline(startedAt, new TrafficBytes(100, 200)),
                TimeZoneInfo.Utc,
                CancellationToken.None);
            var snapshot = await ledger.RecordAsync(
                Delta(
                    startedAt.AddSeconds(1),
                    new TrafficBytes(130, 260),
                    new CategorizedTrafficBytes(
                        new TrafficBytes(10, 20),
                        new TrafficBytes(5, 10),
                        TrafficBytes.Zero,
                        new TrafficBytes(15, 30))),
                TimeZoneInfo.Utc,
                CancellationToken.None);

            Assert.AreEqual(new TrafficBytes(10, 20), snapshot.Today.Proxy);
            Assert.AreEqual(new TrafficBytes(5, 10), snapshot.Today.Direct);
            Assert.AreEqual(new TrafficBytes(15, 30), snapshot.Today.Unknown);
            Assert.AreEqual(snapshot.Today, snapshot.Lifetime);
        }

        await using var reopened = new SQLiteTrafficLedger(_databasePath);
        var restored = await reopened.PrepareAsync(
            TimeZoneInfo.Utc,
            startedAt.AddMinutes(1),
            CancellationToken.None);

        Assert.AreEqual(new TrafficBytes(10, 20), restored.Lifetime.Proxy);
        Assert.AreEqual(new TrafficBytes(5, 10), restored.Lifetime.Direct);
        Assert.AreEqual(new TrafficBytes(15, 30), restored.Lifetime.Unknown);
    }

    [TestMethod]
    public async Task ReconnectBaselineRecordsOnlyNonnegativeGapAsUnknown()
    {
        var startedAt = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);
        await using var ledger = await PreparedLedger(startedAt);
        await ledger.RecordAsync(
            Baseline(startedAt, new TrafficBytes(100, 200)),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(1),
                new TrafficBytes(120, 240),
                Categories(proxy: new TrafficBytes(20, 40))),
            TimeZoneInfo.Utc,
            CancellationToken.None);

        var snapshot = await ledger.RecordAsync(
            Baseline(startedAt.AddSeconds(5), new TrafficBytes(150, 300)),
            TimeZoneInfo.Utc,
            CancellationToken.None);

        Assert.AreEqual(new TrafficBytes(20, 40), snapshot.Lifetime.Proxy);
        Assert.AreEqual(new TrafficBytes(30, 60), snapshot.Lifetime.Unknown);
    }

    [TestMethod]
    public async Task CounterResetStartsNewSessionWithoutClearingHistory()
    {
        var startedAt = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);
        await using var ledger = await PreparedLedger(startedAt);
        await ledger.RecordAsync(
            Baseline(startedAt, new TrafficBytes(100, 200)),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(1),
                new TrafficBytes(120, 240),
                Categories(proxy: new TrafficBytes(20, 40))),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        await ledger.RecordAsync(
            new TrafficLedgerObservation(
                startedAt.AddSeconds(2),
                new TrafficBytes(5, 10),
                new TrafficLedgerCountersReset()),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        await ledger.RecordAsync(
            Baseline(startedAt.AddSeconds(3), new TrafficBytes(5, 10)),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        var snapshot = await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(4),
                new TrafficBytes(8, 16),
                Categories(direct: new TrafficBytes(3, 6))),
            TimeZoneInfo.Utc,
            CancellationToken.None);

        Assert.AreEqual(new TrafficBytes(20, 40), snapshot.Lifetime.Proxy);
        Assert.AreEqual(new TrafficBytes(3, 6), snapshot.Lifetime.Direct);
    }

    [TestMethod]
    public async Task VersionChangeStartsNewSessionWithoutClearingHistory()
    {
        var startedAt = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);
        await using (var ledger = await PreparedLedger(startedAt))
        {
            await ledger.RecordAsync(
                Baseline(startedAt, new TrafficBytes(100, 200)),
                TimeZoneInfo.Utc,
                CancellationToken.None);
            await ledger.RecordAsync(
                Delta(
                    startedAt.AddSeconds(1),
                    new TrafficBytes(120, 240),
                    Categories(proxy: new TrafficBytes(20, 40))),
                TimeZoneInfo.Utc,
                CancellationToken.None);
            await ledger.BeginMonitoringAsync(
                "v1.20.0",
                TimeZoneInfo.Utc,
                startedAt.AddSeconds(2),
                CancellationToken.None);
            await ledger.RecordAsync(
                Baseline(startedAt.AddSeconds(2), new TrafficBytes(5, 10)),
                TimeZoneInfo.Utc,
                CancellationToken.None);
            var snapshot = await ledger.RecordAsync(
                Delta(
                    startedAt.AddSeconds(3),
                    new TrafficBytes(8, 16),
                    Categories(direct: new TrafficBytes(3, 6))),
                TimeZoneInfo.Utc,
                CancellationToken.None);

            Assert.AreEqual(new TrafficBytes(20, 40), snapshot.Lifetime.Proxy);
            Assert.AreEqual(new TrafficBytes(3, 6), snapshot.Lifetime.Direct);
        }

        using var connection = OpenDatabase();
        Assert.AreEqual(2L, ScalarInt64(connection, "SELECT COUNT(*) FROM core_sessions"));
        Assert.AreEqual(
            "version_change",
            ScalarString(
                connection,
                "SELECT end_reason FROM core_sessions WHERE mihomo_version = 'v1.19.29'"));
    }

    [TestMethod]
    public async Task LocalDayChangesTodayWithoutBreakingLifetimeTotals()
    {
        var startedAt = new DateTimeOffset(2026, 8, 7, 23, 59, 58, TimeSpan.Zero);
        await using var ledger = await PreparedLedger(startedAt);
        await ledger.RecordAsync(
            Baseline(startedAt, new TrafficBytes(100, 200)),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(1),
                new TrafficBytes(110, 220),
                Categories(proxy: new TrafficBytes(10, 20))),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        var snapshot = await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(3),
                new TrafficBytes(113, 226),
                Categories(direct: new TrafficBytes(3, 6))),
            TimeZoneInfo.Utc,
            CancellationToken.None);

        Assert.AreEqual(TrafficBytes.Zero, snapshot.Today.Proxy);
        Assert.AreEqual(new TrafficBytes(3, 6), snapshot.Today.Direct);
        Assert.AreEqual(new TrafficBytes(10, 20), snapshot.Lifetime.Proxy);
        Assert.AreEqual(new TrafficBytes(3, 6), snapshot.Lifetime.Direct);
    }

    [TestMethod]
    public async Task TimeZoneChangeWithinMinuteDoesNotRelabelExistingBucket()
    {
        var startedAt = new DateTimeOffset(2026, 1, 1, 12, 0, 0, TimeSpan.Zero);
        var nextDayTimeZone = TimeZoneInfo.CreateCustomTimeZone(
            "Synthetic +14",
            TimeSpan.FromHours(14),
            "Synthetic +14",
            "Synthetic +14");
        await using (var ledger = await PreparedLedger(startedAt))
        {
            await ledger.RecordAsync(
                Baseline(startedAt, new TrafficBytes(100, 200)),
                TimeZoneInfo.Utc,
                CancellationToken.None);
            await ledger.RecordAsync(
                Delta(
                    startedAt.AddSeconds(10),
                    new TrafficBytes(110, 220),
                    Categories(proxy: new TrafficBytes(10, 20))),
                TimeZoneInfo.Utc,
                CancellationToken.None);
            var snapshot = await ledger.RecordAsync(
                Delta(
                    startedAt.AddSeconds(20),
                    new TrafficBytes(113, 226),
                    Categories(direct: new TrafficBytes(3, 6))),
                nextDayTimeZone,
                CancellationToken.None);

            Assert.AreEqual(TrafficBytes.Zero, snapshot.Today.Proxy);
            Assert.AreEqual(new TrafficBytes(3, 6), snapshot.Today.Direct);
            Assert.AreEqual(new TrafficBytes(10, 20), snapshot.Lifetime.Proxy);
            Assert.AreEqual(new TrafficBytes(3, 6), snapshot.Lifetime.Direct);
        }

        using var connection = OpenDatabase();
        Assert.AreEqual(
            1L,
            ScalarInt64(
                connection,
                "SELECT COUNT(*) FROM traffic_buckets "
                    + "WHERE local_day = '2026-01-01' AND category = 'proxy'"));
        Assert.AreEqual(
            1L,
            ScalarInt64(
                connection,
                "SELECT COUNT(*) FROM traffic_buckets "
                    + "WHERE local_day = '2026-01-02' AND category = 'direct'"));
    }

    [TestMethod]
    public async Task PrunesMinuteBucketsOlderThan365DaysButKeepsDailyTotals()
    {
        var startedAt = new DateTimeOffset(2025, 1, 1, 12, 0, 0, TimeSpan.Zero);
        var future = startedAt.AddDays(366);
        TrafficStatisticsSnapshot snapshot;
        await using (var ledger = await PreparedLedger(startedAt))
        {
            await ledger.RecordAsync(
                Baseline(startedAt, new TrafficBytes(100, 200)),
                TimeZoneInfo.Utc,
                CancellationToken.None);
            await ledger.RecordAsync(
                Delta(
                    startedAt.AddSeconds(1),
                    new TrafficBytes(110, 220),
                    Categories(proxy: new TrafficBytes(10, 20))),
                TimeZoneInfo.Utc,
                CancellationToken.None);
            snapshot = await ledger.RecordAsync(
                Delta(
                    future,
                    new TrafficBytes(113, 226),
                    Categories(direct: new TrafficBytes(3, 6))),
                TimeZoneInfo.Utc,
                CancellationToken.None);
        }

        Assert.AreEqual(new TrafficBytes(10, 20), snapshot.Lifetime.Proxy);
        Assert.AreEqual(new TrafficBytes(3, 6), snapshot.Lifetime.Direct);
        using var connection = OpenDatabase();
        Assert.AreEqual(1L, ScalarInt64(connection, "SELECT COUNT(*) FROM traffic_buckets"));
    }

    private async Task<SQLiteTrafficLedger> PreparedLedger(DateTimeOffset startedAt)
    {
        var ledger = new SQLiteTrafficLedger(_databasePath);
        await ledger.PrepareAsync(TimeZoneInfo.Utc, startedAt, CancellationToken.None);
        await ledger.BeginMonitoringAsync(
            "v1.19.29",
            TimeZoneInfo.Utc,
            startedAt,
            CancellationToken.None);
        return ledger;
    }

    private SqliteConnection OpenDatabase()
    {
        var connection = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = _databasePath,
            Pooling = false,
        }.ToString());
        connection.Open();
        return connection;
    }

    private static long ScalarInt64(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        return Convert.ToInt64(command.ExecuteScalar());
    }

    private static string ScalarString(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        return Convert.ToString(command.ExecuteScalar()) ?? string.Empty;
    }

    private static TrafficLedgerObservation Baseline(
        DateTimeOffset observedAt,
        TrafficBytes kernelTotal)
    {
        return new TrafficLedgerObservation(
            observedAt,
            kernelTotal,
            new TrafficLedgerBaselineEstablished());
    }

    private static TrafficLedgerObservation Delta(
        DateTimeOffset observedAt,
        TrafficBytes kernelTotal,
        CategorizedTrafficBytes categories)
    {
        return new TrafficLedgerObservation(
            observedAt,
            kernelTotal,
            new TrafficLedgerDelta(new TrafficDeltaReport(
                categories.Classified,
                categories)));
    }

    private static CategorizedTrafficBytes Categories(
        TrafficBytes? proxy = null,
        TrafficBytes? direct = null,
        TrafficBytes? reject = null,
        TrafficBytes? unknown = null)
    {
        return new CategorizedTrafficBytes(
            proxy ?? TrafficBytes.Zero,
            direct ?? TrafficBytes.Zero,
            reject ?? TrafficBytes.Zero,
            unknown ?? TrafficBytes.Zero);
    }
}
