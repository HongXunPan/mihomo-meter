using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public sealed class TrafficStatisticsCoordinator : ITrafficStatisticsRecorder, IAsyncDisposable
{
    private readonly ITrafficLedger _ledger;
    private readonly TimeProvider _timeProvider;
    private readonly TimeZoneInfo _timeZone;
    private readonly SemaphoreSlim _operationGate = new(1, 1);
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
        await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
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
        finally
        {
            _operationGate.Release();
        }
    }

    public async Task BeginMonitoringAsync(
        string version,
        CancellationToken cancellationToken)
    {
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
        await PerformLedgerOperationAsync(
            token => _ledger.RecordAsync(observation, _timeZone, token),
            cancellationToken).ConfigureAwait(false);
    }

    public async Task InterruptMonitoringAsync(
        TrafficSessionEndReason reason,
        CancellationToken cancellationToken)
    {
        await PerformLedgerOperationAsync(
            token => _ledger.InterruptMonitoringAsync(
                reason,
                _timeZone,
                _timeProvider.GetUtcNow(),
                token),
            cancellationToken,
            interruptIntervalsOnFailure: false).ConfigureAwait(false);
    }

    public Task StartIntervalAsync(
        string name,
        string? note,
        CancellationToken cancellationToken = default)
    {
        return PerformUserOperationAsync(
            token => _ledger.StartIntervalAsync(
                name,
                note,
                _timeZone,
                _timeProvider.GetUtcNow(),
                token),
            cancellationToken);
    }

    public Task StopIntervalAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        return PerformUserOperationAsync(
            token => _ledger.StopIntervalAsync(
                id,
                _timeZone,
                _timeProvider.GetUtcNow(),
                token),
            cancellationToken);
    }

    public Task RenameIntervalAsync(
        Guid id,
        string name,
        CancellationToken cancellationToken = default)
    {
        return PerformUserOperationAsync(
            token => _ledger.RenameIntervalAsync(
                id,
                name,
                _timeZone,
                _timeProvider.GetUtcNow(),
                token),
            cancellationToken);
    }

    public Task DeleteIntervalAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        return PerformUserOperationAsync(
            token => _ledger.DeleteIntervalAsync(
                id,
                _timeZone,
                _timeProvider.GetUtcNow(),
                token),
            cancellationToken);
    }

    public Task ClearAsync(CancellationToken cancellationToken = default)
    {
        return PerformUserOperationAsync(
            token => _ledger.ClearAsync(
                _timeZone,
                _timeProvider.GetUtcNow(),
                token),
            cancellationToken);
    }

    public async ValueTask DisposeAsync()
    {
        await _operationGate.WaitAsync().ConfigureAwait(false);
        try
        {
            await _ledger.DisposeAsync().ConfigureAwait(false);
        }
        finally
        {
            _operationGate.Release();
            _operationGate.Dispose();
        }
    }

    private async Task PerformLedgerOperationAsync(
        Func<CancellationToken, Task<TrafficStatisticsSnapshot>> operation,
        CancellationToken cancellationToken,
        bool interruptIntervalsOnFailure = true)
    {
        await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_currentState.Availability != TrafficStatisticsAvailability.Available)
            {
                return;
            }

            PublishAvailable(await operation(cancellationToken).ConfigureAwait(false));
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            if (interruptIntervalsOnFailure)
            {
                await TryInterruptAfterStatisticsFailureAsync().ConfigureAwait(false);
            }

            PublishUnavailable();
        }
        finally
        {
            _operationGate.Release();
        }
    }

    private async Task PerformUserOperationAsync(
        Func<CancellationToken, Task<TrafficStatisticsSnapshot>> operation,
        CancellationToken cancellationToken)
    {
        await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_currentState.Availability != TrafficStatisticsAvailability.Available)
            {
                return;
            }

            PublishAvailable(await operation(cancellationToken).ConfigureAwait(false));
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception) when (
            exception is ArgumentException or TrafficIntervalOperationException)
        {
            Publish(new TrafficStatisticsState(
                TrafficStatisticsAvailability.Available,
                _currentState.Snapshot,
                exception.Message));
        }
        catch (Exception)
        {
            await TryInterruptAfterStatisticsFailureAsync().ConfigureAwait(false);
            PublishUnavailable();
        }
        finally
        {
            _operationGate.Release();
        }
    }

    private async Task TryInterruptAfterStatisticsFailureAsync()
    {
        try
        {
            var snapshot = await _ledger
                .InterruptActiveIntervalsAsync(
                    TrafficIntervalEndReason.StatisticsUnavailable,
                    _timeZone,
                    _timeProvider.GetUtcNow(),
                    CancellationToken.None)
                .ConfigureAwait(false);
            _currentState = _currentState with { Snapshot = snapshot };
        }
        catch (Exception)
        {
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
