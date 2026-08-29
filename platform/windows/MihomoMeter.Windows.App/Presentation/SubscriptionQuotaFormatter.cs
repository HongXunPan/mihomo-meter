using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

internal static class SubscriptionQuotaFormatter
{
    public static string Bytes(ulong value) => TrafficDisplayFormatter.ByteCount(value);

    public static string UpdatedAt(DateTimeOffset? value, DateTimeOffset now)
    {
        if (value is null)
        {
            return "尚无有效快照";
        }

        return $"{QuotaRelativeTimeFormatter.Format(value.Value, now)}更新";
    }

    public static string Expiration(
        DateTimeOffset? value,
        DateTimeOffset now)
    {
        if (value is null)
        {
            return "未提供到期时间";
        }

        return value <= now
            ? "已到期"
            : $"到期 {TrafficDisplayFormatter.Date(value.Value)}";
    }

    public static string Forecast(QuotaDepletionForecast forecast, DateTimeOffset now)
    {
        if (forecast.EstimatedAt is DateTimeOffset estimatedAt)
        {
            var days = Math.Max((int)Math.Ceiling((estimatedAt - now).TotalDays), 0);
            return days == 0
                ? "可能即将耗尽"
                : $"预计可用约 {QuotaRemainingDurationFormatter.FormatDays(days)}";
        }

        return forecast.UnavailableReason switch
        {
            QuotaForecastUnavailableReason.InsufficientSamples => "样本不足，暂不预测",
            QuotaForecastUnavailableReason.InsufficientObservationSpan => "观察不足 6 小时",
            QuotaForecastUnavailableReason.UnconfirmedCycle => "新周期待确认",
            QuotaForecastUnavailableReason.StaleData => "配额数据已过期",
            QuotaForecastUnavailableReason.NoRecentConsumption => "近期没有可比较消耗",
            QuotaForecastUnavailableReason.Expired => "订阅已到期",
            QuotaForecastUnavailableReason.Depleted => "订阅额度已耗尽",
            _ => "暂不提供耗尽预测",
        };
    }

    public static string QueryStatus(ProfileQuotaQueryState? state, DateTimeOffset now)
    {
        if (state?.LastFailureCategory is string failure)
        {
            var failureText = failure switch
            {
                "timeout" => "最近查询超时，可立即重试",
                "network" => "最近网络查询失败，可立即重试",
                "no_proxy" => "Mihomo 本地代理不可用",
                "missing_header" => "机场未返回配额响应头",
                "invalid_header" => "机场配额格式不受支持",
                _ => "最近查询失败，已保留历史",
            };
            return state.NextAttemptAt is DateTimeOffset retryAt
                ? $"{failureText}；{QuotaRelativeTimeFormatter.Format(retryAt, now)}自动重试"
                : $"{failureText}；等待常规查询";
        }

        if (state?.NextAttemptAt is DateTimeOffset next)
        {
            return $"{QuotaRelativeTimeFormatter.Format(next, now)}自动查询";
        }

        return "等待首次主动查询";
    }

    public static string Event(QuotaEventKind kind)
    {
        return kind switch
        {
            QuotaEventKind.UsageReset => "检测到用量重置",
            QuotaEventKind.TotalIncreased => "检测到总额度增加",
            QuotaEventKind.TotalDecreased => "检测到总额度减少",
            QuotaEventKind.ExpirationChanged => "检测到到期时间变化",
            _ => "检测到配额变化",
        };
    }
}
