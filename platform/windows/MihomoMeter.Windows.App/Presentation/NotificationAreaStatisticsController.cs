using Microsoft.UI.Dispatching;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

internal sealed record NotificationAreaStatisticsTaskSnapshot(
    Guid Id,
    string Name,
    string StatusText,
    string TrafficText,
    string TimeText,
    bool IsActive,
    bool CanStop);

internal sealed record NotificationAreaStatisticsMenuSnapshot(
    int ActiveCount,
    bool CanStart,
    string? Notice,
    IReadOnlyList<NotificationAreaStatisticsTaskSnapshot?> Slots,
    int AdditionalCount);

internal sealed class NotificationAreaStatisticsController : IDisposable
{
    private readonly DispatcherQueue _dispatcherQueue;
    private readonly TrafficMonitoringCoordinator _monitoring;
    private readonly TrafficStatisticsCoordinator _statistics;
    private readonly TimeProvider _timeProvider;
    private readonly TimeZoneInfo _timeZone;
    private TrafficStatisticsState _statisticsState;
    private MonitorConnectionState _monitorState = MonitorConnectionState.Disconnected;
    private bool _disposed;

    public NotificationAreaStatisticsController(
        DispatcherQueue dispatcherQueue,
        TrafficMonitoringCoordinator monitoring,
        TrafficStatisticsCoordinator statistics,
        TimeProvider? timeProvider = null,
        TimeZoneInfo? timeZone = null)
    {
        _dispatcherQueue = dispatcherQueue;
        _monitoring = monitoring;
        _statistics = statistics;
        _timeProvider = timeProvider ?? TimeProvider.System;
        _timeZone = timeZone ?? TimeZoneInfo.Local;
        _statisticsState = statistics.CurrentState;
        _monitoring.SnapshotChanged += Monitoring_SnapshotChanged;
        _statistics.StateChanged += Statistics_StateChanged;
    }

    public NotificationAreaStatisticsMenuSnapshot CaptureSnapshot()
    {
        if (!_dispatcherQueue.HasThreadAccess)
        {
            throw new InvalidOperationException("通知区域统计快照只能在界面线程读取。");
        }

        var quickTasks = TrafficStatisticsQuickTaskProjection.Project(
            _statisticsState.Snapshot.Intervals,
            _timeZone,
            _timeProvider.GetUtcNow());
        var statisticsAvailable = _statisticsState.Availability
            == TrafficStatisticsAvailability.Available;
        var now = _timeProvider.GetUtcNow();
        var slots = quickTasks.Slots
            .Select(slot => CreateTaskSnapshot(
                slot.Interval,
                statisticsAvailable,
                now))
            .ToArray();

        return new NotificationAreaStatisticsMenuSnapshot(
            quickTasks.ActiveCount,
            statisticsAvailable && IsMonitoringAvailable,
            NoticeText(statisticsAvailable),
            Array.AsReadOnly(slots),
            quickTasks.AdditionalCount);
    }

    public Task StartSuggestedIntervalAsync()
    {
        if (_disposed
            || _statisticsState.Availability != TrafficStatisticsAvailability.Available
            || !IsMonitoringAvailable)
        {
            return Task.CompletedTask;
        }

        var name = TrafficStatisticsWorkspaceProjection.SuggestedIntervalName(
            _statisticsState.Snapshot.Intervals);
        return _statistics.StartIntervalAsync(name, null);
    }

    public Task StopIntervalAsync(Guid id)
    {
        if (_disposed
            || _statisticsState.Availability != TrafficStatisticsAvailability.Available
            || !_statisticsState.Snapshot.Intervals.Any(interval =>
                interval.Id == id && interval.Status == TrafficIntervalStatus.Active))
        {
            return Task.CompletedTask;
        }

        return _statistics.StopIntervalAsync(id);
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _monitoring.SnapshotChanged -= Monitoring_SnapshotChanged;
        _statistics.StateChanged -= Statistics_StateChanged;
    }

    private bool IsMonitoringAvailable => _monitorState is
        MonitorConnectionState.Connected
        or MonitorConnectionState.Stale
        or MonitorConnectionState.Reconnecting;

    private void Monitoring_SnapshotChanged(TrafficMonitorSnapshot snapshot)
    {
        if (_dispatcherQueue.HasThreadAccess)
        {
            ApplyMonitoringSnapshotIfCurrent(snapshot);
            return;
        }

        _ = _dispatcherQueue.TryEnqueue(() => ApplyMonitoringSnapshotIfCurrent(snapshot));
    }

    private void Statistics_StateChanged(TrafficStatisticsState state)
    {
        if (_dispatcherQueue.HasThreadAccess)
        {
            ApplyStatisticsState(state);
            return;
        }

        _ = _dispatcherQueue.TryEnqueue(() => ApplyStatisticsState(state));
    }

    private void ApplyMonitoringSnapshotIfCurrent(TrafficMonitorSnapshot snapshot)
    {
        if (!_disposed && _monitoring.IsCurrentSession(snapshot.SessionGeneration))
        {
            _monitorState = snapshot.State;
        }
    }

    private void ApplyStatisticsState(TrafficStatisticsState state)
    {
        if (!_disposed)
        {
            _statisticsState = state;
        }
    }

    private string? NoticeText(bool statisticsAvailable)
    {
        return _statisticsState.Availability switch
        {
            TrafficStatisticsAvailability.Loading => "正在读取本地统计…",
            TrafficStatisticsAvailability.Unavailable =>
                _statisticsState.Message ?? "本地统计暂不可用。",
            _ when !statisticsAvailable => "本地统计暂不可用。",
            _ when !IsMonitoringAvailable => "连接 Mihomo 后可开始新统计。",
            _ => null,
        };
    }

    private static NotificationAreaStatisticsTaskSnapshot? CreateTaskSnapshot(
        TrafficInterval? interval,
        bool statisticsAvailable,
        DateTimeOffset now)
    {
        if (interval is null)
        {
            return null;
        }

        var download = TrafficDisplayFormatter.ByteCount(interval.ProxyUsage.Download);
        var upload = TrafficDisplayFormatter.ByteCount(interval.ProxyUsage.Upload);
        var total = TrafficDisplayFormatter.ByteCount(interval.ProxyUsage.Total);
        return new NotificationAreaStatisticsTaskSnapshot(
            interval.Id,
            interval.Name,
            TrafficDisplayFormatter.IntervalStatus(interval, statisticsAvailable),
            $"下载 {download} · 上传 {upload} · 合计 {total}",
            TrafficDisplayFormatter.IntervalTime(interval, now),
            interval.Status == TrafficIntervalStatus.Active,
            statisticsAvailable && interval.Status == TrafficIntervalStatus.Active);
    }
}
