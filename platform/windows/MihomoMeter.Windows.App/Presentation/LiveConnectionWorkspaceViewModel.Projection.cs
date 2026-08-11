using System.Collections.ObjectModel;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class LiveConnectionWorkspaceViewModel
{
    private readonly ObservableCollection<LiveConnectionRowViewModel> _connections = [];
    private readonly ObservableCollection<LiveConnectionGroupRowViewModel> _groups = [];

    public ObservableCollection<LiveConnectionRowViewModel> Connections => _connections;

    public ObservableCollection<LiveConnectionGroupRowViewModel> Groups => _groups;

    public string StateText => _snapshot.State switch
    {
        MonitorConnectionState.Connected => "实时监控已连接",
        MonitorConnectionState.Stale => "实时数据已过期，列表已清空",
        MonitorConnectionState.Reconnecting => "正在重新连接，列表已清空",
        MonitorConnectionState.Connecting => "正在连接 Mihomo",
        MonitorConnectionState.AuthenticationFailed => "鉴权失败",
        MonitorConnectionState.Unsupported => "响应暂不支持",
        _ => "尚未连接 Mihomo Controller",
    };

    public string ContextTitle => SelectedRoute.Route == LiveConnectionRoute.Proxy
        ? "Proxy 实时连接"
        : "直连实时连接";

    public string ContextDetail => SelectedRoute.Route == LiveConnectionRoute.Proxy
        ? "按连接、应用或域名查看当前 Proxy 速率与累计；连接明细不会持久化。"
        : "仅展示当前 DIRECT 连接；断开、重连、超时或计数器重置会立即清空。";

    public bool IsDiagnosticOpen => SelectedRoute.Route == LiveConnectionRoute.Proxy;

    public string DiagnosticTitle => Diagnostic.Title;

    public string DiagnosticDetail => Diagnostic.Detail;

    public InfoBarSeverity DiagnosticSeverity => Diagnostic.IsWarning
        ? InfoBarSeverity.Warning
        : InfoBarSeverity.Informational;

    public Visibility ConnectionListVisibility =>
        SelectedMode.Mode == LiveConnectionViewMode.Connection && Connections.Count > 0
            ? Visibility.Visible
            : Visibility.Collapsed;

    public Visibility GroupListVisibility =>
        SelectedMode.Mode != LiveConnectionViewMode.Connection && Groups.Count > 0
            ? Visibility.Visible
            : Visibility.Collapsed;

    public Visibility EmptyStateVisibility =>
        (SelectedMode.Mode == LiveConnectionViewMode.Connection
            ? Connections.Count
            : Groups.Count) == 0
                ? Visibility.Visible
                : Visibility.Collapsed;

    public string EmptyStateText => _snapshot.State == MonitorConnectionState.Connected
        ? "当前筛选条件下没有活动连接。"
        : "连接 Mihomo Controller 后将在这里显示活动连接。";

    public string PrimaryColumnTitle => SelectedMode.Mode switch
    {
        LiveConnectionViewMode.Application => "应用",
        LiveConnectionViewMode.Hostname => "域名",
        _ => "连接",
    };

    public string RelationColumnTitle => SelectedMode.Mode == LiveConnectionViewMode.Application
        ? "域名数"
        : "应用数";

    private ApplicationIdentificationDiagnostic Diagnostic =>
        ApplicationIdentificationDiagnostic.Create(
            _snapshot.ProcessMatchingMode,
            _snapshot.AttributionCoverage);

    private IReadOnlyList<LiveTrafficConnection> SourceConnections =>
        LiveConnectionProjection.SourceConnections(
            SelectedRoute.Route,
            _snapshot.LiveProxyConnections,
            _snapshot.LiveDirectConnections);

    private void UpdateRows()
    {
        var connectionRows = LiveConnectionProjection
            .Connections(SourceConnections, SearchText)
            .Select(CreateConnectionRow)
            .ToArray();
        var groupRows = LiveConnectionProjection
            .Groups(SourceConnections, SelectedMode.Mode, SearchText)
            .Select(CreateGroupRow)
            .ToArray();
        ReconcileConnections(connectionRows);
        ReconcileGroups(groupRows);
        NotifyListStateChanged();
    }

    private static LiveConnectionRowViewModel CreateConnectionRow(
        LiveTrafficConnection connection)
    {
        var hostname = LiveConnectionProjection.Hostname(connection);
        var application = LiveConnectionProjection.ApplicationName(connection);
        var downloadRate = TrafficDisplayFormatter.RateValue(
            connection.Rate.DownloadBytesPerSecond);
        var uploadRate = TrafficDisplayFormatter.RateValue(
            connection.Rate.UploadBytesPerSecond);
        var cumulative = $"累计 {TrafficDisplayFormatter.ByteCount(
            connection.CumulativeBytes.Total)}";
        var duration = connection.StartedAt is DateTimeOffset startedAt
            ? $"时长 {TrafficDisplayFormatter.Duration(startedAt, DateTimeOffset.Now)}"
            : "时长 --";
        return new LiveConnectionRowViewModel(
            connection.Id,
            hostname,
            application,
            downloadRate,
            uploadRate,
            cumulative,
            duration,
            $"{hostname}，{application}，下载 {downloadRate}，上传 {uploadRate}，"
                + $"{cumulative}，{duration}");
    }

    private static LiveConnectionGroupRowViewModel CreateGroupRow(
        LiveConnectionGroupRow group)
    {
        var relatedCount = $"{group.RelatedCount}";
        var connectionCount = $"{group.ConnectionCount}";
        var downloadRate = TrafficDisplayFormatter.RateValue(
            group.Rate.DownloadBytesPerSecond);
        var uploadRate = TrafficDisplayFormatter.RateValue(
            group.Rate.UploadBytesPerSecond);
        var cumulative = $"累计 {TrafficDisplayFormatter.ByteCount(
            group.CumulativeBytes.Total)}";
        return new LiveConnectionGroupRowViewModel(
            group.Id,
            group.Name,
            relatedCount,
            connectionCount,
            downloadRate,
            uploadRate,
            cumulative,
            $"{group.Name}，相关项 {relatedCount}，连接 {connectionCount}，"
                + $"下载 {downloadRate}，上传 {uploadRate}，{cumulative}");
    }

    private void ReconcileConnections(IReadOnlyList<LiveConnectionRowViewModel> desired)
    {
        for (var index = 0; index < desired.Count; index += 1)
        {
            var existingIndex = IndexOfConnection(desired[index].Id);
            if (existingIndex < 0)
            {
                _connections.Insert(index, desired[index]);
                continue;
            }

            if (existingIndex != index)
            {
                _connections.Move(existingIndex, index);
            }

            _connections[index].Apply(desired[index]);
        }

        while (_connections.Count > desired.Count)
        {
            _connections.RemoveAt(_connections.Count - 1);
        }
    }

    private void ReconcileGroups(IReadOnlyList<LiveConnectionGroupRowViewModel> desired)
    {
        for (var index = 0; index < desired.Count; index += 1)
        {
            var existingIndex = IndexOfGroup(desired[index].Id);
            if (existingIndex < 0)
            {
                _groups.Insert(index, desired[index]);
                continue;
            }

            if (existingIndex != index)
            {
                _groups.Move(existingIndex, index);
            }

            _groups[index].Apply(desired[index]);
        }

        while (_groups.Count > desired.Count)
        {
            _groups.RemoveAt(_groups.Count - 1);
        }
    }

    private int IndexOfConnection(string id)
    {
        for (var index = 0; index < _connections.Count; index += 1)
        {
            if (string.Equals(_connections[index].Id, id, StringComparison.Ordinal))
            {
                return index;
            }
        }

        return -1;
    }

    private int IndexOfGroup(string id)
    {
        for (var index = 0; index < _groups.Count; index += 1)
        {
            if (string.Equals(_groups[index].Id, id, StringComparison.Ordinal))
            {
                return index;
            }
        }

        return -1;
    }

    private void NotifyContextChanged()
    {
        OnPropertyChanged(nameof(StateText));
        OnPropertyChanged(nameof(ContextTitle));
        OnPropertyChanged(nameof(ContextDetail));
        OnPropertyChanged(nameof(IsDiagnosticOpen));
        OnPropertyChanged(nameof(DiagnosticTitle));
        OnPropertyChanged(nameof(DiagnosticDetail));
        OnPropertyChanged(nameof(DiagnosticSeverity));
        OnPropertyChanged(nameof(EmptyStateText));
    }

    private void NotifyModeChanged()
    {
        OnPropertyChanged(nameof(PrimaryColumnTitle));
        OnPropertyChanged(nameof(RelationColumnTitle));
    }

    private void NotifyListStateChanged()
    {
        OnPropertyChanged(nameof(ConnectionListVisibility));
        OnPropertyChanged(nameof(GroupListVisibility));
        OnPropertyChanged(nameof(EmptyStateVisibility));
        OnPropertyChanged(nameof(EmptyStateText));
    }
}
