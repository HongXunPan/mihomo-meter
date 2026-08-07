using Microsoft.Data.Sqlite;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Statistics;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class TrafficStatisticsBoundaryTests
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
    public async Task RejectsUnsignedByteValuesOutsideSqliteIntegerRange()
    {
        var startedAt = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);
        await using var ledger = new SQLiteTrafficLedger(_databasePath);
        await ledger.PrepareAsync(TimeZoneInfo.Utc, startedAt, CancellationToken.None);
        await ledger.BeginMonitoringAsync(
            "v1.19.29",
            TimeZoneInfo.Utc,
            startedAt,
            CancellationToken.None);
        var unsupported = new TrafficBytes((ulong)long.MaxValue + 1, 0);

        await Assert.ThrowsExactlyAsync<TrafficStatisticsException>(() =>
            ledger.RecordAsync(
                Baseline(startedAt, unsupported),
                TimeZoneInfo.Utc,
                CancellationToken.None));
    }

    [TestMethod]
    public async Task RejectsDatabaseSchemaNewerThanApplication()
    {
        using (var connection = OpenDatabase())
        {
            using var command = connection.CreateCommand();
            command.CommandText = "PRAGMA user_version = 3";
            command.ExecuteNonQuery();
        }

        await using (var ledger = new SQLiteTrafficLedger(_databasePath))
        {
            await Assert.ThrowsExactlyAsync<TrafficStatisticsException>(() =>
                ledger.PrepareAsync(
                    TimeZoneInfo.Utc,
                    DateTimeOffset.UnixEpoch,
                    CancellationToken.None));
        }

        File.Delete(_databasePath);
        Assert.IsFalse(File.Exists(_databasePath));
    }

    [TestMethod]
    public async Task DatabaseSchemaContainsOnlyApprovedAggregateFields()
    {
        await using (var ledger = new SQLiteTrafficLedger(_databasePath))
        {
            await ledger.PrepareAsync(
                TimeZoneInfo.Utc,
                DateTimeOffset.UnixEpoch,
                CancellationToken.None);
        }

        using var connection = OpenDatabase();
        CollectionAssert.AreEqual(
            new[] { "id", "mihomo_version", "started_at", "ended_at", "end_reason" },
            ReadColumnNames(connection, "core_sessions"));
        CollectionAssert.AreEqual(
            new[]
            {
                "bucket_start",
                "local_day",
                "time_zone_id",
                "core_session_id",
                "category",
                "upload_bytes",
                "download_bytes",
            },
            ReadColumnNames(connection, "traffic_buckets"));
        CollectionAssert.AreEqual(
            new[] { "local_day", "category", "upload_bytes", "download_bytes" },
            ReadColumnNames(connection, "traffic_daily_totals"));
        CollectionAssert.AreEqual(
            new[]
            {
                "id",
                "name",
                "note",
                "status",
                "started_at",
                "ended_at",
                "end_reason",
                "start_proxy_upload",
                "start_proxy_download",
                "end_proxy_upload",
                "end_proxy_download",
            },
            ReadColumnNames(connection, "traffic_intervals"));
        CollectionAssert.AreEqual(
            new[]
            {
                "id",
                "current_session_id",
                "current_mihomo_version",
                "last_observed_at",
                "last_kernel_upload",
                "last_kernel_download",
            },
            ReadColumnNames(connection, "ledger_state"));
    }

    [TestMethod]
    public async Task StatisticsFailureKeepsLastSnapshotAndDoesNotThrowToMonitor()
    {
        var snapshot = new TrafficStatisticsSnapshot(
            Categories(proxy: new TrafficBytes(10, 20)),
            Categories(proxy: new TrafficBytes(30, 40)),
            Array.Empty<TrafficInterval>(),
            Array.Empty<TrafficDailyTotal>(),
            DateTimeOffset.UnixEpoch);
        var ledger = new FailingTrafficLedger(snapshot);
        await using var coordinator = new TrafficStatisticsCoordinator(
            ledger,
            timeZone: TimeZoneInfo.Utc);
        await coordinator.PrepareAsync();

        await coordinator.RecordAsync(
            Baseline(DateTimeOffset.UnixEpoch, TrafficBytes.Zero),
            CancellationToken.None);

        Assert.AreEqual(
            TrafficStatisticsAvailability.Unavailable,
            coordinator.CurrentState.Availability);
        Assert.AreEqual(snapshot, coordinator.CurrentState.Snapshot);
        Assert.AreEqual(
            TrafficIntervalEndReason.StatisticsUnavailable,
            ledger.LastInterruptReason);
    }

    [TestMethod]
    public async Task UserOperationConflictKeepsStatisticsAvailableWithMessage()
    {
        var snapshot = TrafficStatisticsSnapshot.Empty;
        await using var coordinator = new TrafficStatisticsCoordinator(
            new FailingTrafficLedger(
                snapshot,
                new TrafficIntervalOperationException("统计任务已经结束。")),
            timeZone: TimeZoneInfo.Utc);
        await coordinator.PrepareAsync();

        await coordinator.StartIntervalAsync("任务", null);

        Assert.AreEqual(
            TrafficStatisticsAvailability.Available,
            coordinator.CurrentState.Availability);
        Assert.AreEqual(snapshot, coordinator.CurrentState.Snapshot);
        Assert.AreEqual("统计任务已经结束。", coordinator.CurrentState.Message);
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

    private static string[] ReadColumnNames(SqliteConnection connection, string table)
    {
        using var command = connection.CreateCommand();
        command.CommandText = $"PRAGMA table_info({table})";
        using var reader = command.ExecuteReader();
        var columns = new List<string>();
        while (reader.Read())
        {
            columns.Add(reader.GetString(1));
        }

        return columns.ToArray();
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

    private static CategorizedTrafficBytes Categories(TrafficBytes? proxy = null)
    {
        return new CategorizedTrafficBytes(
            proxy ?? TrafficBytes.Zero,
            TrafficBytes.Zero,
            TrafficBytes.Zero,
            TrafficBytes.Zero);
    }

    private sealed class FailingTrafficLedger : ITrafficLedger
    {
        private readonly TrafficStatisticsSnapshot _snapshot;
        private readonly Exception? _userOperationException;

        public FailingTrafficLedger(
            TrafficStatisticsSnapshot snapshot,
            Exception? userOperationException = null)
        {
            _snapshot = snapshot;
            _userOperationException = userOperationException;
        }

        public TrafficIntervalEndReason? LastInterruptReason { get; private set; }

        public Task<TrafficStatisticsSnapshot> PrepareAsync(
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(_snapshot);
        }

        public Task<TrafficStatisticsSnapshot> BeginMonitoringAsync(
            string version,
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(_snapshot);
        }

        public Task<TrafficStatisticsSnapshot> RecordAsync(
            TrafficLedgerObservation observation,
            TimeZoneInfo timeZone,
            CancellationToken cancellationToken)
        {
            return Task.FromException<TrafficStatisticsSnapshot>(
                new TrafficStatisticsException("synthetic"));
        }

        public Task<TrafficStatisticsSnapshot> InterruptMonitoringAsync(
            TrafficSessionEndReason reason,
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(_snapshot);
        }

        public Task<TrafficStatisticsSnapshot> StartIntervalAsync(
            string name,
            string? note,
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            return _userOperationException is null
                ? Task.FromResult(_snapshot)
                : Task.FromException<TrafficStatisticsSnapshot>(_userOperationException);
        }

        public Task<TrafficStatisticsSnapshot> StopIntervalAsync(
            Guid id,
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(_snapshot);
        }

        public Task<TrafficStatisticsSnapshot> RenameIntervalAsync(
            Guid id,
            string name,
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(_snapshot);
        }

        public Task<TrafficStatisticsSnapshot> DeleteIntervalAsync(
            Guid id,
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(_snapshot);
        }

        public Task<TrafficStatisticsSnapshot> InterruptActiveIntervalsAsync(
            TrafficIntervalEndReason reason,
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            LastInterruptReason = reason;
            return Task.FromResult(_snapshot);
        }

        public Task<TrafficStatisticsSnapshot> ClearAsync(
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(_snapshot);
        }

        public ValueTask DisposeAsync()
        {
            return ValueTask.CompletedTask;
        }
    }
}
