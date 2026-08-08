using System.ComponentModel;
using System.Runtime.CompilerServices;
using Microsoft.UI.Dispatching;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class ConnectionAnalyticsWorkspaceViewModel : INotifyPropertyChanged
{
    private readonly DispatcherQueue _dispatcherQueue;
    private readonly ConnectionAnalyticsCoordinator _connectionAnalytics;
    private ConnectionAnalyticsState _state;
    private bool _isOperationPending;

    internal ConnectionAnalyticsWorkspaceViewModel(
        DispatcherQueue dispatcherQueue,
        ConnectionAnalyticsCoordinator connectionAnalytics)
    {
        _dispatcherQueue = dispatcherQueue;
        _connectionAnalytics = connectionAnalytics;
        _state = connectionAnalytics.CurrentState;
        _connectionAnalytics.StateChanged += ConnectionAnalytics_StateChanged;
        ApplyState(_state);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    internal Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        return _connectionAnalytics.PrepareAsync(cancellationToken);
    }

    internal Task RefreshAsync(CancellationToken cancellationToken = default)
    {
        return PerformOperationAsync(() => _connectionAnalytics.RefreshAsync(cancellationToken));
    }

    internal Task SetHistoryEnabledAsync(
        bool isEnabled,
        CancellationToken cancellationToken = default)
    {
        return PerformOperationAsync(() =>
            _connectionAnalytics.SetHistoryEnabledAsync(isEnabled, cancellationToken));
    }

    internal Task ClearHistoryAsync(CancellationToken cancellationToken = default)
    {
        return PerformOperationAsync(async () =>
        {
            _ = await _connectionAnalytics.ClearHistoryAsync(cancellationToken)
                .ConfigureAwait(true);
        });
    }

    internal void Detach()
    {
        _connectionAnalytics.StateChanged -= ConnectionAnalytics_StateChanged;
    }

    internal ConnectionAnalyticsTrendTarget TrendTarget(
        ConnectionAnalyticsRankingRowViewModel row)
    {
        return row.Dimension switch
        {
            ConnectionAnalyticsRankingDimension.Application => new ConnectionAnalyticsTrendTarget(
                row.Dimension,
                row.Name,
                new ConnectionAnalyticsTrendQuery(
                    applicationName: row.Name,
                    hostname: SelectedHostnameValue),
                SelectedHostnameValue is null ? null : $"域名：{SelectedHostnameValue}"),
            _ => new ConnectionAnalyticsTrendTarget(
                row.Dimension,
                row.Name,
                new ConnectionAnalyticsTrendQuery(
                    applicationName: SelectedApplicationValue,
                    hostname: row.Name),
                SelectedApplicationValue is null ? null : $"应用：{SelectedApplicationValue}"),
        };
    }

    private async Task PerformOperationAsync(Func<Task> operation)
    {
        if (_isOperationPending)
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

    private void ConnectionAnalytics_StateChanged(ConnectionAnalyticsState state)
    {
        if (_dispatcherQueue.HasThreadAccess)
        {
            ApplyState(state);
            return;
        }
        _ = _dispatcherQueue.TryEnqueue(() => ApplyState(state));
    }

    private void OnPropertyChanged([CallerMemberName] string? name = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
