using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Statistics;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class TrafficIntervalLedgerTests
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
    public async Task OverlappingIntervalsKeepIndependentProxyBaselines()
    {
        var startedAt = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);
        await using var ledger = await PreparedLedger(startedAt);
        await ledger.RecordAsync(
            Baseline(startedAt, TrafficBytes.Zero),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(1),
                new TrafficBytes(100, 200),
                new TrafficBytes(100, 200)),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        var first = await ledger.StartIntervalAsync(
            "任务一",
            null,
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(2),
            CancellationToken.None);
        var firstId = AssertSingle(first, "任务一").Id;

        await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(3),
                new TrafficBytes(150, 270),
                new TrafficBytes(50, 70)),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        var second = await ledger.StartIntervalAsync(
            "任务二",
            "并行",
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(4),
            CancellationToken.None);
        var secondId = AssertSingle(second, "任务二").Id;
        await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(5),
                new TrafficBytes(170, 300),
                new TrafficBytes(20, 30)),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        await ledger.StopIntervalAsync(
            firstId,
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(6),
            CancellationToken.None);
        await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(7),
                new TrafficBytes(175, 310),
                new TrafficBytes(5, 10)),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        var snapshot = await ledger.StopIntervalAsync(
            secondId,
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(8),
            CancellationToken.None);

        var completedFirst = AssertSingle(snapshot, "任务一");
        var completedSecond = AssertSingle(snapshot, "任务二");
        Assert.AreEqual(TrafficIntervalStatus.Completed, completedFirst.Status);
        Assert.AreEqual(TrafficIntervalEndReason.User, completedFirst.EndReason);
        Assert.AreEqual(new TrafficBytes(70, 100), completedFirst.ProxyUsage);
        Assert.AreEqual(new TrafficBytes(25, 40), completedSecond.ProxyUsage);
    }

    [TestMethod]
    public async Task NormalizesRenamesAndDeletesInterval()
    {
        var startedAt = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);
        await using var ledger = await PreparedLedger(startedAt);
        var started = await ledger.StartIntervalAsync(
            "  下载镜像  ",
            "  \r\n  ",
            TimeZoneInfo.Utc,
            startedAt,
            CancellationToken.None);
        var interval = AssertSingle(started, "下载镜像");
        Assert.IsNull(interval.Note);

        var renamed = await ledger.RenameIntervalAsync(
            interval.Id,
            "  更新镜像  ",
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(1),
            CancellationToken.None);
        AssertSingle(renamed, "更新镜像");
        var deleted = await ledger.DeleteIntervalAsync(
            interval.Id,
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(2),
            CancellationToken.None);

        Assert.AreEqual(0, deleted.Intervals.Count);
    }

    [TestMethod]
    public async Task ExplicitExitInterruptsEveryActiveInterval()
    {
        var startedAt = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);
        await using var ledger = await PreparedLedger(startedAt);
        await ledger.RecordAsync(
            Baseline(startedAt, TrafficBytes.Zero),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        await ledger.StartIntervalAsync(
            "退出任务",
            null,
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(1),
            CancellationToken.None);
        await ledger.RecordAsync(
            Delta(
                startedAt.AddSeconds(2),
                new TrafficBytes(12, 34),
                new TrafficBytes(12, 34)),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        var snapshot = await ledger.InterruptMonitoringAsync(
            TrafficSessionEndReason.ApplicationExit,
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(3),
            CancellationToken.None);

        var interval = AssertSingle(snapshot, "退出任务");
        Assert.AreEqual(TrafficIntervalStatus.Interrupted, interval.Status);
        Assert.AreEqual(TrafficIntervalEndReason.ApplicationExit, interval.EndReason);
        Assert.AreEqual(new TrafficBytes(12, 34), interval.ProxyUsage);
        Assert.AreEqual(startedAt.AddSeconds(2), interval.EndedAt);
    }

    [TestMethod]
    public async Task StartupRecoveryInterruptsAbandonedIntervalAtLastObservation()
    {
        var startedAt = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);
        await using (var ledger = await PreparedLedger(startedAt))
        {
            await ledger.RecordAsync(
                Baseline(startedAt, TrafficBytes.Zero),
                TimeZoneInfo.Utc,
                CancellationToken.None);
            await ledger.StartIntervalAsync(
                "恢复任务",
                null,
                TimeZoneInfo.Utc,
                startedAt.AddSeconds(1),
                CancellationToken.None);
            await ledger.RecordAsync(
                Delta(
                    startedAt.AddSeconds(2),
                    new TrafficBytes(40, 80),
                    new TrafficBytes(40, 80)),
                TimeZoneInfo.Utc,
                CancellationToken.None);
        }

        await using var reopened = new SQLiteTrafficLedger(_databasePath);
        var restored = await reopened.PrepareAsync(
            TimeZoneInfo.Utc,
            startedAt.AddMinutes(1),
            CancellationToken.None);
        var interval = AssertSingle(restored, "恢复任务");

        Assert.AreEqual(TrafficIntervalStatus.Interrupted, interval.Status);
        Assert.AreEqual(TrafficIntervalEndReason.Recovery, interval.EndReason);
        Assert.AreEqual(startedAt.AddSeconds(2), interval.EndedAt);
        Assert.AreEqual(new TrafficBytes(40, 80), interval.ProxyUsage);
    }

    [TestMethod]
    public async Task MonitoringAndStatisticsFailuresUseTypedInterruptionReasons()
    {
        var startedAt = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);
        await using var ledger = await PreparedLedger(startedAt);
        await ledger.RecordAsync(
            Baseline(startedAt, TrafficBytes.Zero),
            TimeZoneInfo.Utc,
            CancellationToken.None);
        await ledger.StartIntervalAsync(
            "断开任务",
            null,
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(1),
            CancellationToken.None);
        var stopped = await ledger.InterruptMonitoringAsync(
            TrafficSessionEndReason.MonitoringStopped,
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(2),
            CancellationToken.None);
        Assert.AreEqual(
            TrafficIntervalEndReason.MonitoringStopped,
            AssertSingle(stopped, "断开任务").EndReason);

        await ledger.StartIntervalAsync(
            "故障任务",
            null,
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(3),
            CancellationToken.None);
        var unavailable = await ledger.InterruptActiveIntervalsAsync(
            TrafficIntervalEndReason.StatisticsUnavailable,
            TimeZoneInfo.Utc,
            startedAt.AddSeconds(4),
            CancellationToken.None);
        Assert.AreEqual(
            TrafficIntervalEndReason.StatisticsUnavailable,
            AssertSingle(unavailable, "故障任务").EndReason);
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
