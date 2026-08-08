using System.ComponentModel;
using System.Runtime.CompilerServices;
using Microsoft.UI.Dispatching;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class LiveConnectionWorkspaceViewModel : INotifyPropertyChanged
{
    private static readonly IReadOnlyList<LiveConnectionRouteOption> Routes =
    [
        new(LiveConnectionRoute.Proxy, "Proxy"),
        new(LiveConnectionRoute.Direct, "直连"),
    ];

    private static readonly IReadOnlyList<LiveConnectionModeOption> Modes =
    [
        new(LiveConnectionViewMode.Connection, "连接"),
        new(LiveConnectionViewMode.Application, "应用"),
        new(LiveConnectionViewMode.Hostname, "域名"),
    ];

    private readonly DispatcherQueue _dispatcherQueue;
    private readonly TrafficMonitoringCoordinator _monitoring;
    private TrafficMonitorSnapshot _snapshot = TrafficMonitorSnapshot.Disconnected;
    private LiveConnectionRouteOption _selectedRoute = Routes[0];
    private LiveConnectionModeOption _selectedMode = Modes[0];
    private string _searchText = string.Empty;
    private bool _detached;

    internal LiveConnectionWorkspaceViewModel(
        DispatcherQueue dispatcherQueue,
        TrafficMonitoringCoordinator monitoring)
    {
        _dispatcherQueue = dispatcherQueue;
        _monitoring = monitoring;
        _monitoring.SnapshotChanged += Monitoring_SnapshotChanged;
        UpdateRows();
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public IReadOnlyList<LiveConnectionRouteOption> RouteOptions => Routes;

    public IReadOnlyList<LiveConnectionModeOption> ModeOptions => Modes;

    public LiveConnectionRouteOption SelectedRoute
    {
        get => _selectedRoute;
        set
        {
            if (value is null || Equals(_selectedRoute, value))
            {
                return;
            }

            _selectedRoute = value;
            OnPropertyChanged();
            NotifyContextChanged();
            UpdateRows();
        }
    }

    public LiveConnectionModeOption SelectedMode
    {
        get => _selectedMode;
        set
        {
            if (value is null || Equals(_selectedMode, value))
            {
                return;
            }

            _selectedMode = value;
            OnPropertyChanged();
            NotifyModeChanged();
            UpdateRows();
        }
    }

    public string SearchText
    {
        get => _searchText;
        set
        {
            var normalized = value ?? string.Empty;
            if (string.Equals(_searchText, normalized, StringComparison.Ordinal))
            {
                return;
            }

            _searchText = normalized;
            OnPropertyChanged();
            UpdateRows();
        }
    }

    internal void SelectRoute(LiveConnectionRoute route)
    {
        SelectedRoute = Routes.Single(option => option.Route == route);
    }

    internal void Detach()
    {
        if (_detached)
        {
            return;
        }

        _detached = true;
        _monitoring.SnapshotChanged -= Monitoring_SnapshotChanged;
    }

    private void Monitoring_SnapshotChanged(TrafficMonitorSnapshot snapshot)
    {
        if (_dispatcherQueue.HasThreadAccess)
        {
            ApplySnapshotIfCurrent(snapshot);
            return;
        }

        _ = _dispatcherQueue.TryEnqueue(() => ApplySnapshotIfCurrent(snapshot));
    }

    private void ApplySnapshotIfCurrent(TrafficMonitorSnapshot snapshot)
    {
        if (_detached || !_monitoring.IsCurrentSession(snapshot.SessionGeneration))
        {
            return;
        }

        _snapshot = snapshot;
        NotifyContextChanged();
        UpdateRows();
    }

    private void OnPropertyChanged([CallerMemberName] string? name = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
