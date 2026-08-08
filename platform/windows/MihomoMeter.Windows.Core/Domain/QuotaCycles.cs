namespace MihomoMeter.Windows.Core.Domain;

public enum QuotaCycleStartReason
{
    Initial,
    UsageReset,
}

public sealed record QuotaCycle(
    Guid Id,
    Guid SubscriptionId,
    DateTimeOffset StartedAt,
    DateTimeOffset? EndedAt,
    QuotaCycleStartReason StartReason,
    bool IsUserConfirmed);

public enum QuotaEventKind
{
    UsageReset,
    TotalIncreased,
    TotalDecreased,
    ExpirationChanged,
}

public sealed record QuotaEvent(
    Guid Id,
    Guid SubscriptionId,
    Guid PreviousSnapshotId,
    Guid CurrentSnapshotId,
    DateTimeOffset OccurredAt,
    QuotaEventKind Kind,
    bool IsUserConfirmed);

public sealed record ProfileQuotaQueryState(
    Guid SubscriptionId,
    DateTimeOffset? LastAttemptAt,
    DateTimeOffset? NextAttemptAt,
    string? LastQueriedUrlFingerprint,
    int ConsecutiveFailures,
    DateTimeOffset? RetryDayStart,
    int AutomaticRetryCount,
    string? LastFailureCategory)
{
    public static ProfileQuotaQueryState Empty(Guid subscriptionId) => new(
        subscriptionId,
        null,
        null,
        null,
        0,
        null,
        0,
        null);
}

public static class QuotaCycleDetector
{
    public static bool RequiresNewCycle(
        SubscriptionQuotaSnapshot? previous,
        QuotaObservation current)
    {
        return previous is null || current.Traffic.UsedBytes < previous.Traffic.UsedBytes;
    }
}
