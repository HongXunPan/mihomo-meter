using System.ComponentModel;
using System.Runtime.CompilerServices;
using Microsoft.UI.Dispatching;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class TrafficStatisticsWorkspaceViewModel : INotifyPropertyChanged
{
    private readonly DispatcherQueue _dispatcherQueue;
    private readonly TrafficMonitoringCoordinator _monitoring;
    private readonly TrafficStatisticsCoordinator _statistics;
    private TrafficStatisticsState _statisticsState;
    private MonitorConnectionState _monitorState = MonitorConnectionState.Disconnected;
    private bool _isOperationPending;

    internal TrafficStatisticsWorkspaceViewModel(
        DispatcherQueue dispatcherQueue,
        TrafficMonitoringCoordinator monitoring,
        TrafficStatisticsCoordinator statistics)
    {
        _dispatcherQueue = dispatcherQueue;
        _monitoring = monitoring;
        _statistics = statistics;
        _statisticsState = statistics.CurrentState;
        _monitoring.SnapshotChanged += Monitoring_SnapshotChanged;
        _statistics.StateChanged += Statistics_StateChanged;
        ApplyStatisticsState(_statisticsState);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    internal Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        return _statistics.PrepareAsync(cancellationToken);
    }

    internal Task StartIntervalAsync(
        string name,
        string? note,
        CancellationToken cancellationToken = default)
    {
        return PerformOperationAsync(
            () => _statistics.StartIntervalAsync(name, note, cancellationToken),
            requiresMonitoring: true);
    }

    internal Task StopIntervalAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        return PerformOperationAsync(() => _statistics.StopIntervalAsync(id, cancellationToken));
    }

    internal Task RenameIntervalAsync(
        Guid id,
        string name,
        CancellationToken cancellationToken = default)
    {
        return PerformOperationAsync(() =>
            _statistics.RenameIntervalAsync(id, name, cancellationToken));
    }

    internal Task DeleteIntervalAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        return PerformOperationAsync(() => _statistics.DeleteIntervalAsync(id, cancellationToken));
    }

    internal Task ClearAsync(CancellationToken cancellationToken = default)
    {
        return PerformOperationAsync(() => _statistics.ClearAsync(cancellationToken));
    }

    internal void Detach()
    {
        _monitoring.SnapshotChanged -= Monitoring_SnapshotChanged;
        _statistics.StateChanged -= Statistics_StateChanged;
    }

    private bool StatisticsAvailable => _statisticsState.Availability
        == TrafficStatisticsAvailability.Available;

    private bool IsMonitoringAvailable => _monitorState is
        MonitorConnectionState.Connected
        or MonitorConnectionState.Stale
        or MonitorConnectionState.Reconnecting;

    private async Task PerformOperationAsync(
        Func<Task> operation,
        bool requiresMonitoring = false)
    {
        if (_isOperationPending
            || !StatisticsAvailable
            || (requiresMonitoring && !IsMonitoringAvailable))
        {
            return;
        }

        _isOperationPending = true;
        NotifyOperationAvailability();
        try
        {
            await operation().ConfigureAwait(true);
        }
        finally
        {
            _isOperationPending = false;
            NotifyOperationAvailability();
        }
    }

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
        if (!_monitoring.IsCurrentSession(snapshot.SessionGeneration))
        {
            return;
        }

        _monitorState = snapshot.State;
        OnPropertyChanged(nameof(MonitoringStatusText));
        NotifyOperationAvailability();
    }

    private void OnPropertyChanged([CallerMemberName] string? name = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
