using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Quota;

internal static class QuotaLedgerStorageValues
{
    public static long Bytes(ulong value)
    {
        return value <= long.MaxValue
            ? checked((long)value)
            : throw new QuotaLedgerException("订阅配额超出 SQLite 整数范围。");
    }

    public static ulong Bytes(long value)
    {
        return value >= 0
            ? checked((ulong)value)
            : throw new QuotaLedgerException("订阅配额数据库包含负数字节数。");
    }

    public static string Identity(SubscriptionIdentityMode mode) => mode switch
    {
        SubscriptionIdentityMode.RuntimeSingle => "runtime_single",
        SubscriptionIdentityMode.ClashProfile => "clash_profile",
        _ => throw new QuotaLedgerException("订阅身份模式无效。"),
    };

    public static SubscriptionIdentityMode Identity(string value) => value switch
    {
        "runtime_single" => SubscriptionIdentityMode.RuntimeSingle,
        "clash_profile" => SubscriptionIdentityMode.ClashProfile,
        _ => throw new QuotaLedgerException("订阅身份模式无效。"),
    };

    public static string Status(SubscriptionTrackingStatus status) => status switch
    {
        SubscriptionTrackingStatus.Active => "active",
        SubscriptionTrackingStatus.Paused => "paused",
        SubscriptionTrackingStatus.Archived => "archived",
        SubscriptionTrackingStatus.Unsupported => "unsupported",
        _ => throw new QuotaLedgerException("订阅追踪状态无效。"),
    };

    public static SubscriptionTrackingStatus Status(string value) => value switch
    {
        "active" => SubscriptionTrackingStatus.Active,
        "paused" => SubscriptionTrackingStatus.Paused,
        "archived" => SubscriptionTrackingStatus.Archived,
        "unsupported" => SubscriptionTrackingStatus.Unsupported,
        _ => throw new QuotaLedgerException("订阅追踪状态无效。"),
    };

    public static string Source(QuotaObservationSource source) => source switch
    {
        QuotaObservationSource.MihomoRuntime => "mihomo_runtime",
        QuotaObservationSource.MeterActiveQuery => "meter_active_query",
        _ => throw new QuotaLedgerException("订阅配额来源无效。"),
    };

    public static QuotaObservationSource Source(string value) => value switch
    {
        "mihomo_runtime" => QuotaObservationSource.MihomoRuntime,
        "meter_active_query" => QuotaObservationSource.MeterActiveQuery,
        _ => throw new QuotaLedgerException("订阅配额来源无效。"),
    };

    public static string CycleReason(QuotaCycleStartReason reason) => reason switch
    {
        QuotaCycleStartReason.Initial => "initial",
        QuotaCycleStartReason.UsageReset => "usage_reset",
        _ => throw new QuotaLedgerException("订阅周期原因无效。"),
    };

    public static QuotaCycleStartReason CycleReason(string value) => value switch
    {
        "initial" => QuotaCycleStartReason.Initial,
        "usage_reset" => QuotaCycleStartReason.UsageReset,
        _ => throw new QuotaLedgerException("订阅周期原因无效。"),
    };

    public static string EventKind(QuotaEventKind kind) => kind switch
    {
        QuotaEventKind.UsageReset => "usage_reset",
        QuotaEventKind.TotalIncreased => "total_increased",
        QuotaEventKind.TotalDecreased => "total_decreased",
        QuotaEventKind.ExpirationChanged => "expiration_changed",
        _ => throw new QuotaLedgerException("订阅变化事件无效。"),
    };

    public static QuotaEventKind EventKind(string value) => value switch
    {
        "usage_reset" => QuotaEventKind.UsageReset,
        "total_increased" => QuotaEventKind.TotalIncreased,
        "total_decreased" => QuotaEventKind.TotalDecreased,
        "expiration_changed" => QuotaEventKind.ExpirationChanged,
        _ => throw new QuotaLedgerException("订阅变化事件无效。"),
    };
}
