using Microsoft.Data.Sqlite;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Statistics;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class TrafficLedgerDailyAndClearTests
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
    public async Task SnapshotFillsThirtyLocalProxyDaysWithoutInterpolation()
    {
        var firstDay = new DateTimeOffset(2026, 1, 1, 12, 0, 0, TimeSpan.Zero);
        var lastDay = firstDay.AddDays(29);
        await using var ledger = await PreparedLedger(firstDay);
        await ledger.RecordAsync(
            Baseline(firstDay, TrafficBytes.Zero),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        await ledger.RecordAsync(
            Delta(
                firstDay.AddSeconds(1),
                new TrafficBytes(10, 20),
                new TrafficBytes(10, 20)),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        var snapshot = await ledger.RecordAsync(
            Delta(
                lastDay,
                new TrafficBytes(13, 26),
                new TrafficBytes(3, 6)),
            TimeZoneInfo.Utc,
            CancellationToken.None);

        Assert.AreEqual(30, snapshot.RecentProxyDays.Count);
        Assert.AreEqual("2026-01-01", snapshot.RecentProxyDays[0].LocalDay);
        Assert.AreEqual(new TrafficBytes(10, 20), snapshot.RecentProxyDays[0].Bytes);
        Assert.AreEqual(TrafficBytes.Zero, snapshot.RecentProxyDays[1].Bytes);
        Assert.AreEqual("2026-01-30", snapshot.RecentProxyDays[^1].LocalDay);
        Assert.AreEqual(new TrafficBytes(3, 6), snapshot.RecentProxyDays[^1].Bytes);
    }

    [TestMethod]
    public async Task ClearResetsLedgerAndNextObservationOnlyEstablishesBaseline()
    {
        var startedAt = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);
        await using var ledger = await PreparedLedger(startedAt);
        await ledger.RecordAsync(
            Baseline(startedAt, TrafficBytes.Zero),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        await ledger.StartIntervalAsync(
            "待清空",
            null,
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(1),
            CancellationToken.None);
        await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(2),
                new TrafficBytes(100, 200),
                new TrafficBytes(100, 200)),
            TimeZoneInfo.Utc,
            CancellationToken.None);

        var cleared = await ledger.ClearAsync(
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(3),
            CancellationToken.None);
        Assert.AreEqual(CategorizedTrafficBytes.Zero, cleared.Lifetime);
        Assert.AreEqual(0, cleared.Intervals.Count);
        Assert.IsNull(cleared.LastObservedAt);
        Assert.IsTrue(cleared.RecentProxyDays.All(day => day.Bytes == TrafficBytes.Zero));

        var baseline = await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(4),
                new TrafficBytes(100, 200),
                new TrafficBytes(100, 200)),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        Assert.AreEqual(CategorizedTrafficBytes.Zero, baseline.Lifetime);
        var next = await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(5),
                new TrafficBytes(110, 220),
                new TrafficBytes(10, 20)),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        Assert.AreEqual(new TrafficBytes(10, 20), next.Lifetime.Proxy);
    }

    [TestMethod]
    public async Task FailedClearRollsBackTotalsAndIntervals()
    {
        var startedAt = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);
        await using (var ledger = await PreparedLedger(startedAt))
        {
            await ledger.RecordAsync(
                Baseline(startedAt, TrafficBytes.Zero),
                TimeZoneInfo.Utc,
                CancellationToken.None);
            await ledger.StartIntervalAsync(
                "保留任务",
                null,
                TimeZoneInfo.Utc,
                startedAt.AddSeconds(1),
                CancellationToken.None);
            await ledger.RecordAsync(
                Delta(
                    startedAt.AddSeconds(2),
                    new TrafficBytes(10, 20),
                    new TrafficBytes(10, 20)),
                TimeZoneInfo.Utc,
                CancellationToken.None);
            using (var connection = OpenDatabase())
            {
                using var command = connection.CreateCommand();
                command.CommandText = """
                    CREATE TRIGGER reject_daily_clear
                    BEFORE DELETE ON traffic_daily_totals
                    BEGIN
                      SELECT RAISE(ABORT, 'synthetic');
                    END
                    """;
                command.ExecuteNonQuery();
            }

            await Assert.ThrowsExactlyAsync<TrafficStatisticsException>(() =>
                ledger.ClearAsync(
                    TimeZoneInfo.Utc,
                    startedAt.AddSeconds(3),
                    CancellationToken.None));
        }

        using var preserved = OpenDatabase();
        Assert.AreEqual(1L, ScalarInt64(
            preserved,
            "SELECT COUNT(*) FROM traffic_intervals"));
        Assert.AreEqual(10L, ScalarInt64(
            preserved,
            "SELECT upload_bytes FROM traffic_daily_totals WHERE category = 'proxy'"));
    }

    [TestMethod]
    public async Task PruningMinuteBucketsDoesNotChangeCompletedIntervalUsage()
    {
        var startedAt = new DateTimeOffset(2025, 1, 1, 12, 0, 0, TimeSpan.Zero);
        var future = startedAt.AddDays(366);
        await using var ledger = await PreparedLedger(startedAt);
        await ledger.RecordAsync(
            Baseline(startedAt, TrafficBytes.Zero),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        var started = await ledger.StartIntervalAsync(
            "长期任务",
            null,
            TimeZoneInfo.Utc,
            startedAt,
            CancellationToken.None);
        var id = AssertSingle(started, "长期任务").Id;
        await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(1),
                new TrafficBytes(10, 20),
                new TrafficBytes(10, 20)),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        await ledger.RecordAsync(
            Delta(future, new TrafficBytes(10, 20), TrafficBytes.Zero),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        var completed = await ledger.StopIntervalAsync(
            id,
            TimeZoneInfo.Utc,
            future.AddSeconds(1),
            CancellationToken.None);

        Assert.AreEqual(
            new TrafficBytes(10, 20),
            AssertSingle(completed, "长期任务").ProxyUsage);
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

    private static TrafficInterval AssertSingle(
        TrafficStatisticsSnapshot snapshot,
        string name)
    {
        var matching = snapshot.Intervals.Where(interval => interval.Name == name).ToArray();
        Assert.AreEqual(1, matching.Length);
        return matching[0];
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
        TrafficBytes proxyDelta)
    {
        var categories = new CategorizedTrafficBytes(
            proxyDelta,
            TrafficBytes.Zero,
            TrafficBytes.Zero,
            TrafficBytes.Zero);
        return new TrafficLedgerObservation(
            observedAt,
            kernelTotal,
            new TrafficLedgerDelta(new TrafficDeltaReport(proxyDelta, categories)));
    }
}
