using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class TrafficStatisticsWorkspaceViewModel
{
    private static readonly IReadOnlyList<TrafficStatisticsFilterOption> Filters =
    [
        new(TrafficStatisticsIntervalFilter.Active, "进行中"),
        new(TrafficStatisticsIntervalFilter.History, "历史记录"),
        new(TrafficStatisticsIntervalFilter.All, "全部"),
    ];

    private TrafficStatisticsFilterOption _selectedFilter = Filters[2];
    private IReadOnlyList<TrafficIntervalRowViewModel> _intervals =
        Array.Empty<TrafficIntervalRowViewModel>();
    private IReadOnlyList<TrafficDailyChartPointViewModel> _chartPoints =
        Array.Empty<TrafficDailyChartPointViewModel>();

    public IReadOnlyList<TrafficStatisticsFilterOption> FilterOptions => Filters;

    public TrafficStatisticsFilterOption SelectedFilter
    {
        get => _selectedFilter;
        set
        {
            if (value is null || Equals(_selectedFilter, value))
            {
                return;
            }

            _selectedFilter = value;
            OnPropertyChanged();
            UpdateIntervals();
        }
    }

    public IReadOnlyList<TrafficIntervalRowViewModel> Intervals
    {
        get => _intervals;
        private set
        {
            _intervals = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(IntervalListVisibility));
            OnPropertyChanged(nameof(EmptyStateVisibility));
            OnPropertyChanged(nameof(EmptyStateMessage));
        }
    }

    public IReadOnlyList<TrafficDailyChartPointViewModel> ChartPoints
    {
        get => _chartPoints;
        private set
        {
            _chartPoints = value;
            OnPropertyChanged();
        }
    }

    public Visibility LoadingVisibility => _statisticsState.Availability
        == TrafficStatisticsAvailability.Loading
        ? Visibility.Visible
        : Visibility.Collapsed;

    public Visibility ContentVisibility => _statisticsState.Availability
        == TrafficStatisticsAvailability.Loading
        ? Visibility.Collapsed
        : Visibility.Visible;

    public Visibility IntervalListVisibility => Intervals.Count == 0
        ? Visibility.Collapsed
        : Visibility.Visible;

    public Visibility EmptyStateVisibility => Intervals.Count == 0
        ? Visibility.Visible
        : Visibility.Collapsed;

    public bool IsNoticeOpen => !string.IsNullOrWhiteSpace(_statisticsState.Message)
        || _statisticsState.Availability == TrafficStatisticsAvailability.Unavailable;

    public InfoBarSeverity NoticeSeverity => _statisticsState.Availability
        == TrafficStatisticsAvailability.Unavailable
        ? InfoBarSeverity.Warning
        : InfoBarSeverity.Informational;

    public string NoticeTitle => _statisticsState.Availability
        == TrafficStatisticsAvailability.Unavailable
        ? "本地统计暂不可用"
        : "统计任务提示";

    public string NoticeMessage => _statisticsState.Message
        ?? "本地统计暂不可用，实时监控不受影响。";

    public string StatisticsStatusText => _statisticsState.Availability switch
    {
        TrafficStatisticsAvailability.Loading => "正在准备本地统计。",
        TrafficStatisticsAvailability.Unavailable =>
            "保留最后成功快照；修复账本前不能提交任务操作。",
        TrafficStatisticsAvailability.Available
            when _statisticsState.Snapshot.LastObservedAt is DateTimeOffset observedAt =>
            $"累计更新：{TrafficDisplayFormatter.DateTime(observedAt)}",
        TrafficStatisticsAvailability.Available => "本地统计已就绪，等待首个完整观测。",
        _ => "本地统计状态未知。",
    };

    public string MonitoringStatusText => IsMonitoringAvailable
        ? "实时监控可用，可以开始新的统计任务。"
        : "连接 Mihomo Controller 后才能开始新任务。";

    public string TodayUploadText =>
        TrafficDisplayFormatter.ByteCount(_statisticsState.Snapshot.Today.Proxy.Upload);

    public string TodayDownloadText =>
        TrafficDisplayFormatter.ByteCount(_statisticsState.Snapshot.Today.Proxy.Download);

    public string TodayTotalText =>
        TrafficDisplayFormatter.ByteCount(_statisticsState.Snapshot.Today.Proxy.Total);

    public string LifetimeUploadText =>
        TrafficDisplayFormatter.ByteCount(_statisticsState.Snapshot.Lifetime.Proxy.Upload);

    public string LifetimeDownloadText =>
        TrafficDisplayFormatter.ByteCount(_statisticsState.Snapshot.Lifetime.Proxy.Download);

    public string LifetimeTotalText =>
        TrafficDisplayFormatter.ByteCount(_statisticsState.Snapshot.Lifetime.Proxy.Total);

    public string ActiveCountText =>
        $"{TrafficStatisticsWorkspaceProjection.ActiveIntervalCount(
            _statisticsState.Snapshot.Intervals)} 个进行中";

    public string SuggestedName => TrafficStatisticsWorkspaceProjection
        .SuggestedIntervalName(_statisticsState.Snapshot.Intervals);

    public string RangeTotalText
    {
        get
        {
            var range = CurrentDailyRange();
            return $"30 天合计 {TrafficDisplayFormatter.ByteCount(range.Total.Total)}";
        }
    }

    public string PeakDayText
    {
        get
        {
            var peak = CurrentDailyRange().PeakDay;
            return peak is null || peak.Bytes.Total == 0
                ? "峰值日：暂无流量"
                : $"峰值日：{peak.LocalDay} · "
                    + TrafficDisplayFormatter.ByteCount(peak.Bytes.Total);
        }
    }

    public string RangeDateText
    {
        get
        {
            var days = _statisticsState.Snapshot.RecentProxyDays;
            return days.Count == 0
                ? "最近 30 个本地自然日"
                : $"{days[0].LocalDay} — {days[^1].LocalDay}";
        }
    }

    public string EmptyStateMessage => SelectedFilter.Filter switch
    {
        TrafficStatisticsIntervalFilter.Active => "当前没有进行中的任务。",
        TrafficStatisticsIntervalFilter.History => "尚无已完成或已中断的任务。",
        _ => "点击“开始统计”创建第一个任务。",
    };

    public bool CanStartInterval => StatisticsAvailable
        && IsMonitoringAvailable
        && !_isOperationPending;

    public bool CanClear => StatisticsAvailable && !_isOperationPending;

    private void ApplyStatisticsState(TrafficStatisticsState state)
    {
        _statisticsState = state;
        OnPropertyChanged(nameof(LoadingVisibility));
        OnPropertyChanged(nameof(ContentVisibility));
        OnPropertyChanged(nameof(IsNoticeOpen));
        OnPropertyChanged(nameof(NoticeSeverity));
        OnPropertyChanged(nameof(NoticeTitle));
        OnPropertyChanged(nameof(NoticeMessage));
        OnPropertyChanged(nameof(StatisticsStatusText));
        OnPropertyChanged(nameof(TodayUploadText));
        OnPropertyChanged(nameof(TodayDownloadText));
        OnPropertyChanged(nameof(TodayTotalText));
        OnPropertyChanged(nameof(LifetimeUploadText));
        OnPropertyChanged(nameof(LifetimeDownloadText));
        OnPropertyChanged(nameof(LifetimeTotalText));
        OnPropertyChanged(nameof(ActiveCountText));
        OnPropertyChanged(nameof(SuggestedName));
        OnPropertyChanged(nameof(RangeTotalText));
        OnPropertyChanged(nameof(PeakDayText));
        OnPropertyChanged(nameof(RangeDateText));
        UpdateChart();
        NotifyOperationAvailability();
    }

    private void UpdateChart()
    {
        ChartPoints = CurrentDailyRange().Points
            .Select(TrafficStatisticsWorkspaceModelFactory.ChartPoint)
            .ToArray();
    }

    private void UpdateIntervals()
    {
        var filtered = TrafficStatisticsWorkspaceProjection.FilterIntervals(
            _statisticsState.Snapshot.Intervals,
            SelectedFilter.Filter);
        var now = DateTimeOffset.Now;
        Intervals = filtered
            .Select(interval => TrafficStatisticsWorkspaceModelFactory.IntervalRow(
                interval,
                StatisticsAvailable,
                StatisticsAvailable && !_isOperationPending,
                now))
            .ToArray();
    }

    private TrafficDailyRangeSummary CurrentDailyRange()
    {
        return TrafficStatisticsWorkspaceProjection.DailyRange(
            _statisticsState.Snapshot.RecentProxyDays);
    }

    private void NotifyOperationAvailability()
    {
        OnPropertyChanged(nameof(CanStartInterval));
        OnPropertyChanged(nameof(CanClear));
        UpdateIntervals();
    }
}
