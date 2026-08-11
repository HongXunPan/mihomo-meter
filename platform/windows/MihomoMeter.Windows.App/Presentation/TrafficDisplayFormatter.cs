using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

internal static class TrafficDisplayFormatter
{
    public static string Rate(TrafficRate? rate)
    {
        return rate is null
            ? "↓ --  ·  ↑ --"
            : $"↓ {RateValue(rate.Value.DownloadBytesPerSecond)}  ·  "
                + $"↑ {RateValue(rate.Value.UploadBytesPerSecond)}";
    }

    public static string ByteCount(ulong bytes)
    {
        var nativeText = TrafficDisplayUnits.ByteCount(bytes);
        return SharedCoreTrafficShadow.Observe(
            bytes,
            nativeText,
            SharedCoreTrafficFormat.ByteCount);
    }

    public static string RateValue(ulong bytesPerSecond)
    {
        var nativeText = TrafficDisplayUnits.Rate(bytesPerSecond);
        return SharedCoreTrafficShadow.Observe(
            bytesPerSecond,
            nativeText,
            SharedCoreTrafficFormat.Rate);
    }

    public static string CompactRate(ulong? bytesPerSecond)
    {
        var nativeText = TrafficDisplayUnits.CompactRate(bytesPerSecond);
        return bytesPerSecond is null
            ? nativeText
            : SharedCoreTrafficShadow.Observe(
                bytesPerSecond.Value,
                nativeText,
                SharedCoreTrafficFormat.CompactRate);
    }

    public static string DateTime(DateTimeOffset value)
    {
        return value.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss");
    }

    public static string Percentage(double? rate)
    {
        return rate is null || !double.IsFinite(rate.Value)
            ? "--"
            : $"{Math.Clamp(rate.Value, 0, 1) * 100:0.00}%";
    }

    public static string Duration(DateTimeOffset startedAt, DateTimeOffset endedAt)
    {
        var duration = endedAt > startedAt ? endedAt - startedAt : TimeSpan.Zero;
        var totalSeconds = Math.Max((long)duration.TotalSeconds, 0);
        var days = totalSeconds / 86_400;
        var hours = totalSeconds % 86_400 / 3_600;
        var minutes = totalSeconds % 3_600 / 60;
        var seconds = totalSeconds % 60;
        if (days > 0)
        {
            return $"{days} 天 {hours} 小时";
        }
        if (hours > 0)
        {
            return $"{hours} 小时 {minutes} 分";
        }
        return minutes > 0
            ? $"{minutes} 分 {seconds} 秒"
            : $"{seconds} 秒";
    }

    public static string IntervalTime(TrafficInterval interval, DateTimeOffset now)
    {
        var endedAt = interval.EndedAt ?? now;
        return $"{DateTime(interval.StartedAt)} 开始 · "
            + Duration(interval.StartedAt, endedAt);
    }

    public static string IntervalStatus(
        TrafficInterval interval,
        bool statisticsAvailable)
    {
        if (interval.Status == TrafficIntervalStatus.Active && !statisticsAvailable)
        {
            return "统计异常";
        }

        return interval.Status switch
        {
            TrafficIntervalStatus.Active => "进行中",
            TrafficIntervalStatus.Completed => "已完成",
            TrafficIntervalStatus.Interrupted => interval.EndReason switch
            {
                TrafficIntervalEndReason.ApplicationExit => "已中断 · 应用退出",
                TrafficIntervalEndReason.MonitoringStopped => "已中断 · 监控停止",
                TrafficIntervalEndReason.Recovery => "已中断 · 启动恢复",
                TrafficIntervalEndReason.StatisticsUnavailable => "已中断 · 统计故障",
                _ => "已中断",
            },
            _ => "未知状态",
        };
    }
}
