using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.ConnectionAnalytics;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class ConnectionAnalyticsCoordinatorTests
{
    private string _testDirectory = string.Empty;
    private string _databasePath = string.Empty;
    private readonly DateTimeOffset _now = new(2026, 8, 8, 12, 0, 0, TimeSpan.Zero);

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
    public async Task RecordsOnlyAfterExplicitEnableAndForcedFlush()
    {
        var ledger = new SQLiteConnectionAnalyticsLedger(_databasePath);
        await using var coordinator = Coordinator(ledger);
        await coordinator.PrepareAsync();

        await coordinator.RecordAsync([Delta(1, 2)], _now, CancellationToken.None);
        Assert.AreEqual(0, (await ledger.RecordsAsync(
            "2026-08-08",
            CancellationToken.None)).Count);

        await coordinator.SetHistoryEnabledAsync(true);
        await coordinator.RecordAsync([Delta(3, 4)], _now, CancellationToken.None);
        Assert.AreEqual(0, (await ledger.RecordsAsync(
            "2026-08-08",
            CancellationToken.None)).Count);

        await coordinator.FlushPendingAsync(CancellationToken.None);
        var records = await ledger.RecordsAsync("2026-08-08", CancellationToken.None);
        Assert.AreEqual(1, records.Count);
        Assert.AreEqual(new TrafficBytes(3, 4), records[0].Bytes);
    }

    [TestMethod]
    public async Task CrossingLocalDayFlushesPreviousDayBeforeBufferingNewDay()
    {
        var ledger = new SQLiteConnectionAnalyticsLedger(_databasePath);
        await using var coordinator = Coordinator(ledger);
        await coordinator.PrepareAsync();
        await coordinator.SetHistoryEnabledAsync(true);
        await coordinator.RecordAsync(
            [Delta(1, 2)],
            _now.AddDays(-1),
            CancellationToken.None);

        await coordinator.RecordAsync([Delta(3, 4)], _now, CancellationToken.None);

        Assert.AreEqual(1, (await ledger.RecordsAsync(
            "2026-08-07",
            CancellationToken.None)).Count);
        Assert.AreEqual(0, (await ledger.RecordsAsync(
            "2026-08-08",
            CancellationToken.None)).Count);
        await coordinator.FlushPendingAsync(CancellationToken.None);
        Assert.AreEqual(1, (await ledger.RecordsAsync(
            "2026-08-08",
            CancellationToken.None)).Count);
    }

    [TestMethod]
    public async Task TurningHistoryOffFlushesPendingBytesFirst()
    {
        var ledger = new SQLiteConnectionAnalyticsLedger(_databasePath);
        await using var coordinator = Coordinator(ledger);
        await coordinator.PrepareAsync();
        await coordinator.SetHistoryEnabledAsync(true);
        await coordinator.RecordAsync([Delta(5, 6)], _now, CancellationToken.None);

        await coordinator.SetHistoryEnabledAsync(false);

        var records = await ledger.RecordsAsync("2026-08-08", CancellationToken.None);
        Assert.AreEqual(new TrafficBytes(5, 6), records.Single().Bytes);
        Assert.IsFalse(coordinator.CurrentState.Snapshot.IsHistoryEnabled);
    }

    [TestMethod]
    public async Task RecordingFailureDegradesOnlyAnalyticsState()
    {
        await using var coordinator = new ConnectionAnalyticsCoordinator(
            new ThrowingRecordLedger(Snapshot(isEnabled: true)),
            timeProvider: new FixedTimeProvider(_now),
            timeZone: TimeZoneInfo.Utc);
        await coordinator.PrepareAsync();

        await coordinator.RecordAsync([Delta(1, 2)], _now, CancellationToken.None);
        await coordinator.FlushPendingAsync(CancellationToken.None);

        Assert.AreEqual(
            ConnectionAnalyticsAvailability.Unavailable,
            coordinator.CurrentState.Availability);
    }

    [TestMethod]
    public async Task CoreTrafficFailureOnlyMakesRecordingCoverageUnavailable()
    {
        var ledger = new SQLiteConnectionAnalyticsLedger(_databasePath);
        await using var coordinator = new ConnectionAnalyticsCoordinator(
            ledger,
            new ThrowingProxyDailyTrafficProvider(),
            new FixedTimeProvider(_now),
            TimeZoneInfo.Utc);

        await coordinator.PrepareAsync();

        Assert.AreEqual(
            ConnectionAnalyticsAvailability.Available,
            coordinator.CurrentState.Availability);
        Assert.IsNull(coordinator.CurrentState.RecordingCoverage);
    }

    private ConnectionAnalyticsCoordinator Coordinator(
        IConnectionAnalyticsLedger ledger)
    {
        return new ConnectionAnalyticsCoordinator(
            ledger,
            timeProvider: new FixedTimeProvider(_now),
            timeZone: TimeZoneInfo.Utc);
    }

    private static ConnectionAttributionDelta Delta(ulong upload, ulong download)
    {
        return new ConnectionAttributionDelta(
            new ConnectionMetadata("example.test", "Browser"),
            new TrafficBytes(upload, download));
    }

    private ConnectionAnalyticsLedgerSnapshot Snapshot(bool isEnabled)
    {
        return new ConnectionAnalyticsLedgerSnapshot(
            isEnabled,
            ConnectionAnalyticsCalendar.RecentLocalDays(_now, TimeZoneInfo.Utc)
                .Select(day => new ConnectionAnalyticsDay(
                    day,
                    TrafficBytes.Zero,
                    ConnectionAnalyticsCoverage.Empty))
                .ToArray());
    }

    private sealed class FixedTimeProvider : TimeProvider
    {
        private readonly DateTimeOffset _now;

        public FixedTimeProvider(DateTimeOffset now)
        {
            _now = now;
        }

        public override DateTimeOffset GetUtcNow()
        {
            return _now;
        }
    }

    private sealed class ThrowingProxyDailyTrafficProvider : IProxyDailyTrafficProvider
    {
        public Task<TrafficBytes> ProxyTrafficAsync(
            string localDay,
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            throw new InvalidOperationException("模拟核心总账查询失败");
        }
    }

    private sealed class ThrowingRecordLedger : IConnectionAnalyticsLedger
    {
        private readonly ConnectionAnalyticsLedgerSnapshot _snapshot;

        public ThrowingRecordLedger(ConnectionAnalyticsLedgerSnapshot snapshot)
        {
            _snapshot = snapshot;
        }

        public Task<ConnectionAnalyticsLedgerSnapshot> PrepareAsync(
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(_snapshot);
        }

        public Task<ConnectionAnalyticsLedgerSnapshot> SetHistoryEnabledAsync(
            bool isEnabled,
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(_snapshot);
        }

        public Task<ConnectionAnalyticsLedgerSnapshot> RecordAsync(
            IReadOnlyList<ConnectionAttributionAggregate> aggregates,
            int maximumPairCountPerDay,
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            throw new ConnectionAnalyticsException("模拟归因写入失败");
        }

        public Task<IReadOnlyList<ConnectionAttributionRecord>> RecordsAsync(
            string localDay,
            CancellationToken cancellationToken)
        {
            return Task.FromResult<IReadOnlyList<ConnectionAttributionRecord>>([]);
        }

        public Task<ConnectionAnalyticsTrend> TrendAsync(
            ConnectionAnalyticsTrendQuery query,
            TimeZoneInfo timeZone,
            DateTimeOffset now,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(new ConnectionAnalyticsTrend([]));
        }

        public Task<ConnectionAnalyticsLedgerSnapshot> ClearHistoryAsync(
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
