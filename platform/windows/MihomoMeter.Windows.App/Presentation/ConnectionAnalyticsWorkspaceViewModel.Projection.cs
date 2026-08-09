using System.Collections.ObjectModel;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class ConnectionAnalyticsWorkspaceViewModel
{
    private readonly ObservableCollection<ConnectionAnalyticsDayOptionViewModel> _dayOptions = [];
    private readonly ObservableCollection<ConnectionAnalyticsFilterOptionViewModel>
        _applicationOptions = [];
    private readonly ObservableCollection<ConnectionAnalyticsFilterOptionViewModel>
        _hostnameOptions = [];
    private readonly ObservableCollection<ConnectionAnalyticsRankingRowViewModel>
        _applicationRanking = [];
    private readonly ObservableCollection<ConnectionAnalyticsRankingRowViewModel>
        _hostnameRanking = [];
    private ConnectionAnalyticsDayOptionViewModel? _selectedDay;
    private ConnectionAnalyticsFilterOptionViewModel? _selectedApplication;
    private ConnectionAnalyticsFilterOptionViewModel? _selectedHostname;

    public ObservableCollection<ConnectionAnalyticsDayOptionViewModel> DayOptions => _dayOptions;

    public ObservableCollection<ConnectionAnalyticsFilterOptionViewModel> ApplicationOptions =>
        _applicationOptions;

    public ObservableCollection<ConnectionAnalyticsFilterOptionViewModel> HostnameOptions =>
        _hostnameOptions;

    public ObservableCollection<ConnectionAnalyticsRankingRowViewModel> ApplicationRanking =>
        _applicationRanking;

    public ObservableCollection<ConnectionAnalyticsRankingRowViewModel> HostnameRanking =>
        _hostnameRanking;

    public ConnectionAnalyticsDayOptionViewModel? SelectedDay
    {
        get => _selectedDay;
        set
        {
            if (value is null
                || string.Equals(
                    value.LocalDay,
                    _selectedDay?.LocalDay,
                    StringComparison.Ordinal))
            {
                return;
            }
            _selectedDay = value;
            OnPropertyChanged();
            _ = _connectionAnalytics.SelectDayAsync(value.LocalDay);
        }
    }

    public ConnectionAnalyticsFilterOptionViewModel? SelectedApplication
    {
        get => _selectedApplication;
        set
        {
            if (value is null || Equals(value, _selectedApplication))
            {
                return;
            }
            _selectedApplication = value;
            OnPropertyChanged();
            UpdateRankings();
        }
    }

    public ConnectionAnalyticsFilterOptionViewModel? SelectedHostname
    {
        get => _selectedHostname;
        set
        {
            if (value is null || Equals(value, _selectedHostname))
            {
                return;
            }
            _selectedHostname = value;
            OnPropertyChanged();
            UpdateRankings();
        }
    }

    public bool IsHistoryEnabled => _state.Snapshot.IsHistoryEnabled;

    public bool CanOperate =>
        _state.Availability == ConnectionAnalyticsAvailability.Available
        && !_isOperationPending;

    public bool CanClear => CanOperate
        && _state.Snapshot.RecentDays.Any(day => day.Bytes.Total > 0);

    public Visibility LoadingVisibility => _state.Availability
        == ConnectionAnalyticsAvailability.Loading
            ? Visibility.Visible
            : Visibility.Collapsed;

    public Visibility ContentVisibility => _state.Availability
        == ConnectionAnalyticsAvailability.Loading
            ? Visibility.Collapsed
            : Visibility.Visible;

    public bool IsNoticeOpen => _state.Availability == ConnectionAnalyticsAvailability.Unavailable
        || !string.IsNullOrWhiteSpace(_state.Message);

    public InfoBarSeverity NoticeSeverity => _state.Availability
        == ConnectionAnalyticsAvailability.Unavailable
            ? InfoBarSeverity.Warning
            : InfoBarSeverity.Informational;

    public string NoticeTitle => _state.Availability == ConnectionAnalyticsAvailability.Unavailable
        ? "历史归因暂不可用"
        : "历史归因提示";

    public string NoticeMessage => _state.Message
        ?? "连接归因暂不可用，实时监控、核心流量统计和配额不受影响。";

    public string RecordingCoverageText => TrafficDisplayFormatter.Percentage(
        _state.RecordingCoverage?.Rate);

    public string RecordingCoverageDetail => _state.RecordingCoverage is { } coverage
        ? $"已归因 {TrafficDisplayFormatter.ByteCount(coverage.Attributed.Total)} · "
            + $"核心 Proxy {TrafficDisplayFormatter.ByteCount(coverage.CoreProxy.Total)}"
        : "核心 Proxy 总账暂不可用，榜单与趋势仍可使用。";

    public string HostnameCoverageText => TrafficDisplayFormatter.Percentage(
        SelectedAnalyticsDay?.Coverage.HostnameRate);

    public string ApplicationCoverageText => TrafficDisplayFormatter.Percentage(
        SelectedAnalyticsDay?.Coverage.ApplicationRate);

    public string FullyAttributedCoverageText => TrafficDisplayFormatter.Percentage(
        SelectedAnalyticsDay?.Coverage.FullyAttributedRate);

    public string AttributedTotalText =>
        $"当日已记录 {TrafficDisplayFormatter.ByteCount(SelectedAnalyticsDay?.Bytes.Total ?? 0)}";

    public Visibility ApplicationEmptyVisibility => _applicationRanking.Count == 0
        ? Visibility.Visible
        : Visibility.Collapsed;

    public Visibility HostnameEmptyVisibility => _hostnameRanking.Count == 0
        ? Visibility.Visible
        : Visibility.Collapsed;

    private string? SelectedApplicationValue => _selectedApplication?.Value;

    private string? SelectedHostnameValue => _selectedHostname?.Value;

    private ConnectionAnalyticsDay? SelectedAnalyticsDay =>
        _state.Snapshot.RecentDays.FirstOrDefault(day => string.Equals(
            day.LocalDay,
            _state.SelectedLocalDay,
            StringComparison.Ordinal));

    private void ApplyState(ConnectionAnalyticsState state)
    {
        _state = state;
        SyncDays();
        SyncFilters();
        UpdateRankings();
        OnPropertyChanged(nameof(IsHistoryEnabled));
        OnPropertyChanged(nameof(LoadingVisibility));
        OnPropertyChanged(nameof(ContentVisibility));
        OnPropertyChanged(nameof(IsNoticeOpen));
        OnPropertyChanged(nameof(NoticeSeverity));
        OnPropertyChanged(nameof(NoticeTitle));
        OnPropertyChanged(nameof(NoticeMessage));
        OnPropertyChanged(nameof(RecordingCoverageText));
        OnPropertyChanged(nameof(RecordingCoverageDetail));
        OnPropertyChanged(nameof(HostnameCoverageText));
        OnPropertyChanged(nameof(ApplicationCoverageText));
        OnPropertyChanged(nameof(FullyAttributedCoverageText));
        OnPropertyChanged(nameof(AttributedTotalText));
        NotifyOperationAvailability();
    }

    private void SyncDays()
    {
        var desiredDays = _state.Snapshot.RecentDays
            .Select(day => new ConnectionAnalyticsDayOptionViewModel(day.LocalDay, day.LocalDay))
            .ToArray();
        SyncOptions(_dayOptions, desiredDays, item => item.LocalDay);
        _selectedDay = _dayOptions.FirstOrDefault(item => string.Equals(
            item.LocalDay,
            _state.SelectedLocalDay,
            StringComparison.Ordinal));
        OnPropertyChanged(nameof(SelectedDay));
    }

    private void SyncFilters()
    {
        var applications = new[]
        {
            new ConnectionAnalyticsFilterOptionViewModel(null, "全部应用"),
        }.Concat(ConnectionAnalyticsWorkspaceProjection
            .ApplicationNames(_state.SelectedRecords)
            .Select(name => new ConnectionAnalyticsFilterOptionViewModel(name, name)))
            .ToArray();
        var hostnames = new[]
        {
            new ConnectionAnalyticsFilterOptionViewModel(null, "全部域名"),
        }.Concat(ConnectionAnalyticsWorkspaceProjection
            .Hostnames(_state.SelectedRecords)
            .Select(name => new ConnectionAnalyticsFilterOptionViewModel(name, name)))
            .ToArray();
        var applicationValue = applications.Any(item => item.Value == SelectedApplicationValue)
            ? SelectedApplicationValue
            : null;
        var hostnameValue = hostnames.Any(item => item.Value == SelectedHostnameValue)
            ? SelectedHostnameValue
            : null;
        SyncOptions(_applicationOptions, applications, item => item.Value ?? string.Empty);
        SyncOptions(_hostnameOptions, hostnames, item => item.Value ?? string.Empty);
        _selectedApplication = _applicationOptions.First(item => item.Value == applicationValue);
        _selectedHostname = _hostnameOptions.First(item => item.Value == hostnameValue);
        OnPropertyChanged(nameof(SelectedApplication));
        OnPropertyChanged(nameof(SelectedHostname));
    }

    private void UpdateRankings()
    {
        var applications = ConnectionAnalyticsWorkspaceProjection.ApplicationRanking(
            _state.SelectedRecords,
            SelectedApplicationValue,
            SelectedHostnameValue);
        var hostnames = ConnectionAnalyticsWorkspaceProjection.HostnameRanking(
            _state.SelectedRecords,
            SelectedApplicationValue,
            SelectedHostnameValue);
        SyncRanking(
            _applicationRanking,
            ConnectionAnalyticsRankingDimension.Application,
            applications);
        SyncRanking(
            _hostnameRanking,
            ConnectionAnalyticsRankingDimension.Hostname,
            hostnames);
        OnPropertyChanged(nameof(ApplicationEmptyVisibility));
        OnPropertyChanged(nameof(HostnameEmptyVisibility));
    }

    private void NotifyOperationAvailability()
    {
        OnPropertyChanged(nameof(CanOperate));
        OnPropertyChanged(nameof(CanClear));
    }

    private static void SyncOptions<T>(
        ObservableCollection<T> target,
        IEnumerable<T> desired,
        Func<T, string> key)
    {
        var items = desired.ToArray();
        for (var index = 0; index < items.Length; index += 1)
        {
            var desiredItem = items[index];
            var existingIndex = IndexOf(target, key(desiredItem), key);
            if (existingIndex < 0)
            {
                target.Insert(index, desiredItem);
            }
            else if (existingIndex != index)
            {
                target.Move(existingIndex, index);
            }
        }
        while (target.Count > items.Length)
        {
            target.RemoveAt(target.Count - 1);
        }
    }

    private static int IndexOf<T>(
        IReadOnlyList<T> items,
        string desiredKey,
        Func<T, string> key)
    {
        for (var index = 0; index < items.Count; index += 1)
        {
            if (string.Equals(key(items[index]), desiredKey, StringComparison.Ordinal))
            {
                return index;
            }
        }
        return -1;
    }

    private static void SyncRanking(
        ObservableCollection<ConnectionAnalyticsRankingRowViewModel> target,
        ConnectionAnalyticsRankingDimension dimension,
        IReadOnlyList<ConnectionAnalyticsRankingItem> desired)
    {
        for (var index = 0; index < desired.Count; index += 1)
        {
            var item = desired[index];
            var existingIndex = IndexOf(target, item.Name, row => row.Name);
            if (existingIndex < 0)
            {
                target.Insert(index, new ConnectionAnalyticsRankingRowViewModel(
                    dimension,
                    item.Name,
                    item.Bytes));
                continue;
            }
            if (existingIndex != index)
            {
                target.Move(existingIndex, index);
            }
            target[index].Apply(item.Bytes);
        }
        while (target.Count > desired.Count)
        {
            target.RemoveAt(target.Count - 1);
        }
    }
}
