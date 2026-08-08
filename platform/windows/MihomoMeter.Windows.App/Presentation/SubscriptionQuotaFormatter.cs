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

        var elapsed = now - value.Value;
        if (elapsed < TimeSpan.FromMinutes(1))
        {
            return "刚刚更新";
        }

        if (elapsed < TimeSpan.FromHours(1))
        {
            return $"{Math.Max((int)elapsed.TotalMinutes, 1)} 分钟前更新";
        }

        if (elapsed < TimeSpan.FromDays(1))
        {
            return $"{Math.Max((int)elapsed.TotalHours, 1)} 小时前更新";
        }

        return TrafficDisplayFormatter.DateTime(value.Value);
    }

    public static string Forecast(QuotaDepletionForecast forecast, DateTimeOffset now)
    {
        if (forecast.EstimatedAt is DateTimeOffset estimatedAt)
        {
            var days = Math.Max((int)Math.Ceiling((estimatedAt - now).TotalDays), 0);
            return $"预计可用 {days} 天 · {estimatedAt.LocalDateTime:yyyy-MM-dd}";
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
            return failure switch
            {
                "timeout" => "最近查询超时，可立即重试",
                "network" => "最近网络查询失败，可立即重试",
                "no_proxy" => "Mihomo 本地代理不可用",
                "missing_header" => "机场未返回配额响应头",
                "invalid_header" => "机场配额格式不受支持",
                _ => "最近查询失败，已保留历史",
            };
        }

        if (state?.NextAttemptAt is DateTimeOffset next)
        {
            return next <= now + TimeSpan.FromMinutes(1)
                ? "即将自动查询"
                : $"下次查询 {next.LocalDateTime:MM-dd HH:mm}";
        }

        return "等待首次主动查询";
    }
}
