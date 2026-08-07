using Microsoft.UI.Xaml;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed record TrafficStatisticsFilterOption(
    TrafficStatisticsIntervalFilter Filter,
    string Title);

public sealed record TrafficIntervalRowViewModel(
    Guid Id,
    string Name,
    string NoteText,
    Visibility NoteVisibility,
    string StatusText,
    string TimeText,
    string DownloadText,
    string UploadText,
    string TotalText,
    Visibility StopVisibility,
    bool CanOperate,
    string AutomationName);

public sealed record TrafficDailyChartPointViewModel(
    string LocalDay,
    double UploadHeight,
    double DownloadHeight,
    string AutomationName);

internal static class TrafficStatisticsWorkspaceModelFactory
{
    private const double ChartHeight = 112;

    public static TrafficIntervalRowViewModel IntervalRow(
        TrafficInterval interval,
        bool statisticsAvailable,
        bool canOperate,
        DateTimeOffset now)
    {
        var statusText = StatusText(interval, statisticsAvailable);
        var endedAt = interval.EndedAt ?? now;
        var noteText = interval.Note ?? string.Empty;
        var download = TrafficDisplayFormatter.ByteCount(interval.ProxyUsage.Download);
        var upload = TrafficDisplayFormatter.ByteCount(interval.ProxyUsage.Upload);
        var total = TrafficDisplayFormatter.ByteCount(interval.ProxyUsage.Total);
        return new TrafficIntervalRowViewModel(
            interval.Id,
            interval.Name,
            noteText,
            noteText.Length == 0 ? Visibility.Collapsed : Visibility.Visible,
            statusText,
            $"{TrafficDisplayFormatter.DateTime(interval.StartedAt)} 开始 · "
                + TrafficDisplayFormatter.Duration(interval.StartedAt, endedAt),
            $"↓ {download}",
            $"↑ {upload}",
            $"合计 {total}",
            interval.Status == TrafficIntervalStatus.Active
                ? Visibility.Visible
                : Visibility.Collapsed,
            canOperate,
            $"{interval.Name}，{statusText}，下载 {download}，上传 {upload}，合计 {total}");
    }

    public static TrafficDailyChartPointViewModel ChartPoint(TrafficDailyChartPoint point)
    {
        var download = TrafficDisplayFormatter.ByteCount(point.Bytes.Download);
        var upload = TrafficDisplayFormatter.ByteCount(point.Bytes.Upload);
        var total = TrafficDisplayFormatter.ByteCount(point.Bytes.Total);
        return new TrafficDailyChartPointViewModel(
            point.LocalDay,
            point.UploadFraction * ChartHeight,
            point.DownloadFraction * ChartHeight,
            $"{point.LocalDay}，下载 {download}，上传 {upload}，合计 {total}");
    }

    private static string StatusText(
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
