using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public sealed partial class ConnectionAnalyticsCoordinator
{
    public async Task<ConnectionAnalyticsTrend> TrendAsync(
        ConnectionAnalyticsTrendQuery query,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(query);
        await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            ObjectDisposedException.ThrowIf(_disposed, this);
            if (_currentState.Availability != ConnectionAnalyticsAvailability.Available)
            {
                throw new ConnectionAnalyticsException("连接归因账本暂不可用。");
            }

            await FlushPendingForTrendAsync(cancellationToken).ConfigureAwait(false);
            return await _ledger.TrendAsync(
                query,
                _timeZone,
                _timeProvider.GetUtcNow(),
                cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _operationGate.Release();
        }
    }

    public async Task<bool> ClearHistoryAsync(CancellationToken cancellationToken = default)
    {
        await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_disposed)
            {
                return false;
            }

            _ = CancelScheduledFlushLocked();
            _pending.Clear();
            if (_currentState.Availability != ConnectionAnalyticsAvailability.Available)
            {
                Publish(_currentState with
                {
                    Message = "连接归因历史暂不可用，清空操作未执行。",
                });
                return false;
            }

            var snapshot = await _ledger.ClearHistoryAsync(
                _timeZone,
                _timeProvider.GetUtcNow(),
                cancellationToken).ConfigureAwait(false);
            await PublishAvailableSnapshotAsync(
                snapshot,
                snapshot.RecentDays.LastOrDefault()?.LocalDay,
                cancellationToken).ConfigureAwait(false);
            return true;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            PublishUnavailable(exception);
            return false;
        }
        finally
        {
            _operationGate.Release();
        }
    }

    public async ValueTask DisposeAsync()
    {
        Task? scheduledTask;
        await _operationGate.WaitAsync().ConfigureAwait(false);
        try
        {
            if (_disposed)
            {
                return;
            }

            scheduledTask = CancelScheduledFlushLocked();
            _ = await FlushPendingCoreAsync(
                CancellationToken.None,
                publishSnapshot: false).ConfigureAwait(false);
            _disposed = true;
        }
        finally
        {
            _operationGate.Release();
        }

        if (scheduledTask is not null)
        {
            await ObserveScheduledFlushAsync(scheduledTask).ConfigureAwait(false);
        }

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
}
