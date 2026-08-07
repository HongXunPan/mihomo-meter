using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public sealed class TrafficStatisticsCoordinator : ITrafficStatisticsRecorder, IAsyncDisposable
{
    private readonly ITrafficLedger _ledger;
    private readonly TimeProvider _timeProvider;
    private readonly TimeZoneInfo _timeZone;
    private TrafficStatisticsState _currentState = TrafficStatisticsState.Loading;

    public TrafficStatisticsCoordinator(
        ITrafficLedger ledger,
        TimeProvider? timeProvider = null,
        TimeZoneInfo? timeZone = null)
    {
        _ledger = ledger;
        _timeProvider = timeProvider ?? TimeProvider.System;
        _timeZone = timeZone ?? TimeZoneInfo.Local;
    }

    public event Action<TrafficStatisticsState>? StateChanged;

    public TrafficStatisticsState CurrentState => _currentState;

    public async Task PrepareAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var snapshot = await _ledger
                .PrepareAsync(
                    _timeZone,
                    _timeProvider.GetUtcNow(),
                    cancellationToken)
                .ConfigureAwait(false);
            PublishAvailable(snapshot);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            PublishUnavailable();
        }
    }

    public async Task BeginMonitoringAsync(
        string version,
        CancellationToken cancellationToken)
    {
        if (_currentState.Availability != TrafficStatisticsAvailability.Available)
        {
            return;
        }

        await PerformLedgerOperationAsync(
            token => _ledger.BeginMonitoringAsync(
                version,
                _timeZone,
                _timeProvider.GetUtcNow(),
                token),
            cancellationToken).ConfigureAwait(false);
    }

    public async Task RecordAsync(
        TrafficLedgerObservation observation,
        CancellationToken cancellationToken)
    {
        if (_currentState.Availability != TrafficStatisticsAvailability.Available)
        {
            return;
        }

        await PerformLedgerOperationAsync(
            token => _ledger.RecordAsync(observation, _timeZone, token),
            cancellationToken).ConfigureAwait(false);
    }

    public async Task InterruptMonitoringAsync(
        TrafficSessionEndReason reason,
        CancellationToken cancellationToken)
    {
        if (_currentState.Availability != TrafficStatisticsAvailability.Available)
        {
            return;
        }

        await PerformLedgerOperationAsync(
            token => _ledger.InterruptMonitoringAsync(
                reason,
                _timeZone,
                _timeProvider.GetUtcNow(),
                token),
            cancellationToken).ConfigureAwait(false);
    }

    public ValueTask DisposeAsync()
    {
        return _ledger.DisposeAsync();
    }

    private async Task PerformLedgerOperationAsync(
        Func<CancellationToken, Task<TrafficStatisticsSnapshot>> operation,
        CancellationToken cancellationToken)
    {
        try
        {
            PublishAvailable(await operation(cancellationToken).ConfigureAwait(false));
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            PublishUnavailable();
        }
    }

    private void PublishAvailable(TrafficStatisticsSnapshot snapshot)
    {
        Publish(new TrafficStatisticsState(
            TrafficStatisticsAvailability.Available,
            snapshot));
    }

    private void PublishUnavailable()
    {
        Publish(new TrafficStatisticsState(
            TrafficStatisticsAvailability.Unavailable,
            _currentState.Snapshot,
            "本地统计暂不可用，实时监控不受影响。"));
    }

    private void Publish(TrafficStatisticsState state)
    {
        _currentState = state;
        StateChanged?.Invoke(state);
    }
}
