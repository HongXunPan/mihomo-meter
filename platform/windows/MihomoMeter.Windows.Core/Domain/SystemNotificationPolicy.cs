namespace MihomoMeter.Windows.Core.Domain;

public enum QuotaNotificationKind
{
    LowRemaining,
    ExpiringSoon,
    DepletingSoon,
}

public sealed record SystemNotificationDelivery(
    string DeduplicationKey,
    string Title,
    string Body,
    AppActivationTarget Target);

public static class QuotaSystemNotificationPolicy
{
    public static readonly TimeSpan MaximumSnapshotAge = TimeSpan.FromMinutes(15);
    public static readonly TimeSpan UpcomingInterval = TimeSpan.FromDays(3);

    public static IReadOnlyList<SystemNotificationDelivery> Deliveries(
        IEnumerable<SubscriptionQuotaAnalysis> analyses,
        DateTimeOffset now)
    {
        var deliveries = new List<SystemNotificationDelivery>();
        foreach (var analysis in analyses)
        {
            var snapshot = analysis.LatestSnapshot;
            var cycle = analysis.CurrentCycle;
            if (analysis.Subscription.Status != SubscriptionTrackingStatus.Active
                || snapshot is null
                || cycle is null
                || !cycle.IsUserConfirmed
                || cycle.Id != snapshot.CycleId
                || !IsFresh(snapshot.ObservedAt, now))
            {
                continue;
            }

            if (snapshot.Traffic.RemainingBytes <= snapshot.Traffic.TotalBytes / 10)
            {
                deliveries.Add(Delivery(analysis, QuotaNotificationKind.LowRemaining));
            }

            if (IsUpcoming(snapshot.ExpireAt, now))
            {
                deliveries.Add(Delivery(analysis, QuotaNotificationKind.ExpiringSoon));
            }

            if (IsUpcoming(analysis.Forecast.EstimatedAt, now))
            {
                deliveries.Add(Delivery(analysis, QuotaNotificationKind.DepletingSoon));
            }
        }

        return deliveries;
    }

    private static bool IsFresh(DateTimeOffset observedAt, DateTimeOffset now)
    {
        return observedAt <= now && now - observedAt <= MaximumSnapshotAge;
    }

    private static bool IsUpcoming(DateTimeOffset? date, DateTimeOffset now)
    {
        return date > now && date - now <= UpcomingInterval;
    }

    private static SystemNotificationDelivery Delivery(
        SubscriptionQuotaAnalysis analysis,
        QuotaNotificationKind kind)
    {
        var key = string.Join(
            '|',
            "quota",
            analysis.Subscription.Id.ToString("D"),
            analysis.CurrentCycle!.Id.ToString("D"),
            KindValue(kind));
        return kind switch
        {
            QuotaNotificationKind.LowRemaining => new SystemNotificationDelivery(
                key,
                "订阅配额不足",
                "有一项订阅的剩余配额已不高于 10%，请打开订阅余额查看。",
                AppActivationTarget.SubscriptionQuota),
            QuotaNotificationKind.ExpiringSoon => new SystemNotificationDelivery(
                key,
                "订阅即将过期",
                "有一项订阅将在 3 天内过期，请打开订阅余额查看。",
                AppActivationTarget.SubscriptionQuota),
            QuotaNotificationKind.DepletingSoon => new SystemNotificationDelivery(
                key,
                "订阅配额预计即将耗尽",
                "有一项订阅预计将在 3 天内耗尽，请打开订阅余额查看。",
                AppActivationTarget.SubscriptionQuota),
            _ => throw new ArgumentOutOfRangeException(nameof(kind)),
        };
    }

    private static string KindValue(QuotaNotificationKind kind)
    {
        return kind switch
        {
            QuotaNotificationKind.LowRemaining => "lowRemaining",
            QuotaNotificationKind.ExpiringSoon => "expiringSoon",
            QuotaNotificationKind.DepletingSoon => "depletingSoon",
            _ => throw new ArgumentOutOfRangeException(nameof(kind)),
        };
    }
}

public static class ConnectionSystemNotificationPolicy
{
    public static readonly TimeSpan SustainedDisconnectionInterval = TimeSpan.FromMinutes(10);
    public const string DeduplicationKey = "connection|sustained-disconnection";

    public static readonly SystemNotificationDelivery Delivery = new(
        DeduplicationKey,
        "Mihomo 连接持续中断",
        "连接已连续 10 分钟未恢复，请打开连接设置检查。",
        AppActivationTarget.ControllerSettings);

    public static bool ShouldNotify(
        DateTimeOffset? disconnectedSince,
        DateTimeOffset now)
    {
        return disconnectedSince <= now
            && now - disconnectedSince >= SustainedDisconnectionInterval;
    }
}
