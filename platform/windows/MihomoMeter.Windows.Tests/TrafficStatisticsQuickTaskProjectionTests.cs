using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class TrafficStatisticsQuickTaskProjectionTests
{
    private static readonly DateTimeOffset Now = new(
        2026,
        8,
        8,
        12,
        0,
        0,
        TimeSpan.Zero);

    [TestMethod]
    public void KeepsFiveStableSlotsWithActiveTasksBeforeTodayEndedTasks()
    {
        var recentActive = Interval(
            "最近进行中",
            TrafficIntervalStatus.Active,
            Now.AddMinutes(-5));
        var earlierActive = Interval(
            "较早进行中",
            TrafficIntervalStatus.Active,
            Now.AddMinutes(-20));
        var todayCompleted = Interval(
            "今日完成",
            TrafficIntervalStatus.Completed,
            Now.AddHours(-2),
            Now.AddMinutes(-10));
        var yesterdayInterrupted = Interval(
            "昨日中断",
            TrafficIntervalStatus.Interrupted,
            Now.AddDays(-1),
            Now.AddDays(-1).AddHours(1));

        var snapshot = TrafficStatisticsQuickTaskProjection.Project(
            [todayCompleted, earlierActive, yesterdayInterrupted, recentActive],
            TimeZoneInfo.Utc,
            Now);

        Assert.AreEqual(2, snapshot.ActiveCount);
        Assert.AreEqual(TrafficStatisticsQuickTaskProjection.SlotCount, snapshot.Slots.Count);
        CollectionAssert.AreEqual(
            new[] { "最近进行中", "较早进行中", "今日完成" },
            snapshot.Slots
                .Select(slot => slot.Interval?.Name)
                .Where(name => name is not null)
                .ToArray());
        CollectionAssert.AreEqual(
            new[] { 0, 1, 2, 3, 4 },
            snapshot.Slots.Select(slot => slot.Index).ToArray());
        Assert.IsNull(snapshot.Slots[3].Interval);
        Assert.IsNull(snapshot.Slots[4].Interval);
        Assert.AreEqual(0, snapshot.AdditionalCount);
    }

    [TestMethod]
    public void ReportsOverflowAndKeepsSlotTaskIdentityStable()
    {
        var intervals = Enumerable.Range(0, 7)
            .Select(index => Interval(
                $"任务 {index}",
                TrafficIntervalStatus.Active,
                Now.AddMinutes(index)))
            .ToArray();

        var snapshot = TrafficStatisticsQuickTaskProjection.Project(
            intervals,
            TimeZoneInfo.Utc,
            Now);

        Assert.AreEqual(7, snapshot.ActiveCount);
        Assert.AreEqual(2, snapshot.AdditionalCount);
        CollectionAssert.AreEqual(
            new[] { "任务 6", "任务 5", "任务 4", "任务 3", "任务 2" },
            snapshot.Slots.Select(slot => slot.Interval?.Name).ToArray());
        CollectionAssert.AreEqual(
            new[]
            {
                intervals[6].Id,
                intervals[5].Id,
                intervals[4].Id,
                intervals[3].Id,
                intervals[2].Id,
            },
            snapshot.Slots.Select(slot => slot.Interval!.Id).ToArray());
    }

    [TestMethod]
    public void UsesRequestedTimeZoneWhenSelectingTodayEndedTasks()
    {
        var chinaTimeZone = TimeZoneInfo.CreateCustomTimeZone(
            "测试东八区",
            TimeSpan.FromHours(8),
            "测试东八区",
            "测试东八区");
        var utcYesterdayButLocalToday = Interval(
            "本地今日完成",
            TrafficIntervalStatus.Completed,
            Now.AddHours(-14),
            new DateTimeOffset(2026, 8, 7, 16, 30, 0, TimeSpan.Zero));

        var snapshot = TrafficStatisticsQuickTaskProjection.Project(
            [utcYesterdayButLocalToday],
            chinaTimeZone,
            new DateTimeOffset(2026, 8, 8, 1, 0, 0, TimeSpan.Zero));

        Assert.AreEqual("本地今日完成", snapshot.Slots[0].Interval?.Name);
    }

    private static TrafficInterval Interval(
        string name,
        TrafficIntervalStatus status,
        DateTimeOffset startedAt,
        DateTimeOffset? endedAt = null)
    {
        return new TrafficInterval(
            Guid.NewGuid(),
            name,
            null,
            status,
            startedAt,
            status == TrafficIntervalStatus.Active
                ? null
                : endedAt ?? startedAt.AddMinutes(1),
            status switch
            {
                TrafficIntervalStatus.Active => null,
                TrafficIntervalStatus.Completed => TrafficIntervalEndReason.User,
                _ => TrafficIntervalEndReason.Recovery,
            },
            new TrafficBytes(1_024, 2_048));
    }
}
