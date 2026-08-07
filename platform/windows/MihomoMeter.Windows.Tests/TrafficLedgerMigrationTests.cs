using Microsoft.Data.Sqlite;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Statistics;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class TrafficLedgerMigrationTests
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
    public async Task MigratesVersionOneWithoutChangingExistingTotals()
    {
        using (var connection = OpenDatabase())
        {
            CreateVersionOneDatabase(connection);
            Execute(connection, """
                INSERT INTO traffic_daily_totals(
                  local_day, category, upload_bytes, download_bytes
                ) VALUES ('2026-08-08', 'proxy', 11, 22)
                """);
        }

        await using (var ledger = new SQLiteTrafficLedger(_databasePath))
        {
            var snapshot = await ledger.PrepareAsync(
                TimeZoneInfo.Utc,
                new DateTimeOffset(2026, 8, 8, 12, 0, 0, TimeSpan.Zero),
                CancellationToken.None);
            Assert.AreEqual(new TrafficBytes(11, 22), snapshot.Lifetime.Proxy);
            Assert.AreEqual(0, snapshot.Intervals.Count);
        }

        using var migrated = OpenDatabase();
        Assert.AreEqual(2L, ScalarInt64(migrated, "PRAGMA user_version"));
        Assert.AreEqual(1L, ScalarInt64(
            migrated,
            "SELECT COUNT(*) FROM traffic_daily_totals"));
        Assert.AreEqual(1L, ScalarInt64(
            migrated,
            "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'traffic_intervals'"));
    }

    [TestMethod]
    public async Task FailedVersionOneMigrationRollsBackVersionAndPreservesTotals()
    {
        using (var connection = OpenDatabase())
        {
            CreateVersionOneDatabase(connection);
            Execute(connection, "CREATE TABLE traffic_intervals(id TEXT)");
            Execute(connection, """
                INSERT INTO traffic_daily_totals(
                  local_day, category, upload_bytes, download_bytes
                ) VALUES ('2026-08-08', 'proxy', 33, 44)
                """);
        }

        await using (var ledger = new SQLiteTrafficLedger(_databasePath))
        {
            await Assert.ThrowsExactlyAsync<TrafficStatisticsException>(() =>
                ledger.PrepareAsync(
                    TimeZoneInfo.Utc,
                    DateTimeOffset.UnixEpoch,
                    CancellationToken.None));
        }

        using var preserved = OpenDatabase();
        Assert.AreEqual(1L, ScalarInt64(preserved, "PRAGMA user_version"));
        Assert.AreEqual(33L, ScalarInt64(
            preserved,
            "SELECT upload_bytes FROM traffic_daily_totals WHERE category = 'proxy'"));
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

    private static void CreateVersionOneDatabase(SqliteConnection connection)
    {
        Execute(connection, """
            CREATE TABLE core_sessions (
              id TEXT PRIMARY KEY,
              mihomo_version TEXT NOT NULL,
              started_at INTEGER NOT NULL,
              ended_at INTEGER,
              end_reason TEXT
            )
            """);
        Execute(connection, """
            CREATE TABLE traffic_buckets (
              bucket_start INTEGER NOT NULL,
              local_day TEXT NOT NULL,
              time_zone_id TEXT NOT NULL,
              core_session_id TEXT NOT NULL,
              category TEXT NOT NULL,
              upload_bytes INTEGER NOT NULL CHECK(upload_bytes >= 0),
              download_bytes INTEGER NOT NULL CHECK(download_bytes >= 0),
              PRIMARY KEY(
                bucket_start,
                local_day,
                time_zone_id,
                core_session_id,
                category
              ),
              FOREIGN KEY(core_session_id) REFERENCES core_sessions(id)
            )
            """);
        Execute(connection, """
            CREATE TABLE traffic_daily_totals (
              local_day TEXT NOT NULL,
              category TEXT NOT NULL,
              upload_bytes INTEGER NOT NULL CHECK(upload_bytes >= 0),
              download_bytes INTEGER NOT NULL CHECK(download_bytes >= 0),
              PRIMARY KEY(local_day, category)
            )
            """);
        Execute(connection, """
            CREATE TABLE ledger_state (
              id INTEGER PRIMARY KEY CHECK(id = 1),
              current_session_id TEXT,
              current_mihomo_version TEXT,
              last_observed_at INTEGER,
              last_kernel_upload INTEGER,
              last_kernel_download INTEGER
            )
            """);
        Execute(connection, "INSERT INTO ledger_state(id) VALUES (1)");
        Execute(connection, "PRAGMA user_version = 1");
    }

    private static void Execute(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }

    private static long ScalarInt64(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        return Convert.ToInt64(command.ExecuteScalar());
    }
}
