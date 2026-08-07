using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

internal static class TrafficDisplayFormatter
{
    public static string Rate(TrafficRate? rate)
    {
        return rate is null
            ? "↑ --  ·  ↓ --"
            : $"↑ {ByteCount(rate.Value.UploadBytesPerSecond)}/s  ·  "
                + $"↓ {ByteCount(rate.Value.DownloadBytesPerSecond)}/s";
    }

    public static string ByteCount(ulong bytes)
    {
        const double kibibyte = 1_024;
        const double mebibyte = 1_024 * 1_024;
        const double gibibyte = 1_024 * 1_024 * 1_024;
        return bytes switch
        {
            >= (ulong)gibibyte => $"{bytes / gibibyte:0.0} GiB",
            >= (ulong)mebibyte => $"{bytes / mebibyte:0.0} MiB",
            >= (ulong)kibibyte => $"{bytes / kibibyte:0.0} KiB",
            _ => $"{bytes} B",
        };
    }

    public static string DateTime(DateTimeOffset value)
    {
        return value.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss");
    }

    public static string Duration(DateTimeOffset startedAt, DateTimeOffset endedAt)
    {
        var duration = endedAt > startedAt ? endedAt - startedAt : TimeSpan.Zero;
        return duration.TotalDays >= 1
            ? $"{(int)duration.TotalDays}天 {duration:hh\\:mm\\:ss}"
            : duration.ToString("hh\\:mm\\:ss");
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
