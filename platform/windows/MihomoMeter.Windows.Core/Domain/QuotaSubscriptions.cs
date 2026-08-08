namespace MihomoMeter.Windows.Core.Domain;

public enum SubscriptionIdentityMode
{
    RuntimeSingle,
    ClashProfile,
}

public enum SubscriptionTrackingStatus
{
    Active,
    Paused,
    Archived,
    Unsupported,
}

public sealed record TrackedSubscription
{
    public TrackedSubscription(
        Guid id,
        string name,
        SubscriptionIdentityMode identityMode,
        string? clashProfileUid,
        string? urlFingerprint,
        int? refreshIntervalMinutes,
        SubscriptionTrackingStatus status,
        DateTimeOffset createdAt,
        DateTimeOffset updatedAt)
    {
        var normalizedName = name.Trim();
        if (id == Guid.Empty || normalizedName.Length == 0 || createdAt > updatedAt)
        {
            throw new QuotaDomainException("订阅身份数据无效。");
        }

        var normalizedUid = NormalizeOptional(clashProfileUid);
        var normalizedFingerprint = NormalizeOptional(urlFingerprint);
        switch (identityMode)
        {
            case SubscriptionIdentityMode.RuntimeSingle:
                if (normalizedUid is not null
                    || normalizedFingerprint is not null
                    || refreshIntervalMinutes is not null)
                {
                    throw new QuotaDomainException("轻量订阅身份包含不允许的 Profile 字段。");
                }

                break;
            case SubscriptionIdentityMode.ClashProfile:
                if (normalizedUid is null
                    || normalizedFingerprint is null
                    || !AllowedRefreshIntervals.Contains(refreshIntervalMinutes ?? 0))
                {
                    throw new QuotaDomainException("Profile 订阅身份或查询间隔无效。");
                }

                break;
            default:
                throw new QuotaDomainException("订阅身份模式无效。");
        }

        Id = id;
        Name = normalizedName;
        IdentityMode = identityMode;
        ClashProfileUid = normalizedUid;
        UrlFingerprint = normalizedFingerprint;
        RefreshIntervalMinutes = refreshIntervalMinutes;
        Status = status;
        CreatedAt = createdAt;
        UpdatedAt = updatedAt;
    }

    public static IReadOnlySet<int> AllowedRefreshIntervals { get; } =
        new HashSet<int> { 60, 180, 360, 720, 1_440 };

    public Guid Id { get; }

    public string Name { get; }

    public SubscriptionIdentityMode IdentityMode { get; }

    public string? ClashProfileUid { get; }

    public string? UrlFingerprint { get; }

    public int? RefreshIntervalMinutes { get; }

    public SubscriptionTrackingStatus Status { get; }

    public DateTimeOffset CreatedAt { get; }

    public DateTimeOffset UpdatedAt { get; }

    private static string? NormalizeOptional(string? value)
    {
        var normalized = value?.Trim();
        return string.IsNullOrEmpty(normalized) ? null : normalized;
    }
}

public enum QuotaObservationSource
{
    MihomoRuntime,
    MeterActiveQuery,
}

public sealed record QuotaObservation(
    Guid SubscriptionId,
    DateTimeOffset ObservedAt,
    DateTimeOffset? SourceUpdatedAt,
    QuotaObservationSource Source,
    QuotaTraffic Traffic,
    DateTimeOffset? ExpireAt)
{
    public DateTimeOffset EffectiveAt => SourceUpdatedAt ?? ObservedAt;
}

public sealed record SubscriptionQuotaSnapshot(
    Guid Id,
    Guid SubscriptionId,
    Guid CycleId,
    DateTimeOffset ObservedAt,
    DateTimeOffset? SourceUpdatedAt,
    QuotaObservationSource Source,
    QuotaTraffic Traffic,
    DateTimeOffset? ExpireAt)
{
    public DateTimeOffset EffectiveAt => SourceUpdatedAt ?? ObservedAt;
}
