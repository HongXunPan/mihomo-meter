using System.Collections.ObjectModel;
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
    private readonly ObservableCollection<TrafficIntervalRowViewModel> _intervalItems = [];
    private readonly ObservableCollection<TrafficDailyChartPointViewModel> _chartPointItems = [];
    private TrafficDailyRangeSummary _dailyRange =
        TrafficStatisticsWorkspaceProjection.DailyRange(Array.Empty<TrafficDailyTotal>());

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
            OnPropertyChanged(nameof(EmptyStateMessage));
            UpdateIntervals();
        }
    }

    public ObservableCollection<TrafficIntervalRowViewModel> Intervals => _intervalItems;

    public ObservableCollection<TrafficDailyChartPointViewModel> ChartPoints => _chartPointItems;

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
            return $"30 天合计 {TrafficDisplayFormatter.ByteCount(_dailyRange.Total.Total)}";
        }
    }

    public string PeakDayText
    {
        get
        {
            var peak = _dailyRange.PeakDay;
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

    public string ChartAxisMaximumText =>
        TrafficDisplayFormatter.ByteCount(_dailyRange.AxisTicks.Maximum);

    public string ChartAxisThreeQuarterText =>
        TrafficDisplayFormatter.ByteCount(_dailyRange.AxisTicks.ThreeQuarters);

    public string ChartAxisHalfText =>
        TrafficDisplayFormatter.ByteCount(_dailyRange.AxisTicks.Half);

    public string ChartAxisQuarterText =>
        TrafficDisplayFormatter.ByteCount(_dailyRange.AxisTicks.Quarter);

    private void ApplyStatisticsState(TrafficStatisticsState state)
    {
        _statisticsState = state;
        _dailyRange = TrafficStatisticsWorkspaceProjection.DailyRange(
            state.Snapshot.RecentProxyDays);
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
        OnPropertyChanged(nameof(ChartAxisMaximumText));
        OnPropertyChanged(nameof(ChartAxisThreeQuarterText));
        OnPropertyChanged(nameof(ChartAxisHalfText));
        OnPropertyChanged(nameof(ChartAxisQuarterText));
        UpdateChart();
        NotifyOperationAvailability();
    }

    private void UpdateChart()
    {
        var desired = _dailyRange.Points
            .Select(TrafficStatisticsWorkspaceModelFactory.ChartPoint)
            .ToArray();
        for (var index = 0; index < desired.Length; index += 1)
        {
            var desiredPoint = desired[index];
            var existingIndex = IndexOfChartDay(desiredPoint.LocalDay);
            if (existingIndex < 0)
            {
                _chartPointItems.Insert(index, desiredPoint);
                continue;
            }

            if (existingIndex != index)
            {
                _chartPointItems.Move(existingIndex, index);
            }

            _chartPointItems[index].Apply(desiredPoint);
        }

        while (_chartPointItems.Count > desired.Length)
        {
            _chartPointItems.RemoveAt(_chartPointItems.Count - 1);
        }
    }

    private void UpdateIntervals()
    {
        var filtered = TrafficStatisticsWorkspaceProjection.FilterIntervals(
            _statisticsState.Snapshot.Intervals,
            SelectedFilter.Filter);
        var now = DateTimeOffset.Now;
        var desired = filtered
            .Select(interval => TrafficStatisticsWorkspaceModelFactory.IntervalRow(
                interval,
                StatisticsAvailable,
                StatisticsAvailable && !_isOperationPending,
                now))
            .ToArray();
        var previousCount = _intervalItems.Count;
        for (var index = 0; index < desired.Length; index += 1)
        {
            var desiredRow = desired[index];
            var existingIndex = IndexOfInterval(desiredRow.Id);
            if (existingIndex < 0)
            {
                _intervalItems.Insert(index, desiredRow);
                continue;
            }

            if (existingIndex != index)
            {
                _intervalItems.Move(existingIndex, index);
            }

            _intervalItems[index].Apply(desiredRow);
        }

        while (_intervalItems.Count > desired.Length)
        {
            _intervalItems.RemoveAt(_intervalItems.Count - 1);
        }

        if (previousCount != _intervalItems.Count)
        {
            OnPropertyChanged(nameof(IntervalListVisibility));
            OnPropertyChanged(nameof(EmptyStateVisibility));
            OnPropertyChanged(nameof(EmptyStateMessage));
        }
    }

    private void NotifyOperationAvailability()
    {
        OnPropertyChanged(nameof(CanStartInterval));
        OnPropertyChanged(nameof(CanClear));
        UpdateIntervals();
    }

    private int IndexOfInterval(Guid id)
    {
        for (var index = 0; index < _intervalItems.Count; index += 1)
        {
            if (_intervalItems[index].Id == id)
            {
                return index;
            }
        }

        return -1;
    }

    private int IndexOfChartDay(string localDay)
    {
        for (var index = 0; index < _chartPointItems.Count; index += 1)
        {
            if (string.Equals(
                _chartPointItems[index].LocalDay,
                localDay,
                StringComparison.Ordinal))
            {
                return index;
            }
        }

        return -1;
    }
}
