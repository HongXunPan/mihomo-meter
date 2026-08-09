using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public sealed partial class ConnectionAnalyticsCoordinator
{
    public async Task RecordAsync(
        IReadOnlyList<ConnectionAttributionDelta> deltas,
        DateTimeOffset observedAt,
        CancellationToken cancellationToken)
    {
        try
        {
            await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            return;
        }

        try
        {
            if (_disposed
                || _currentState.Availability != ConnectionAnalyticsAvailability.Available
                || !_currentState.Snapshot.IsHistoryEnabled
                || deltas.Count == 0)
            {
                return;
            }

            var localDay = ConnectionAnalyticsCalendar.LocalDay(observedAt, _timeZone);
            if (_pending.Keys.Any(key =>
                !string.Equals(key.LocalDay, localDay, StringComparison.Ordinal))
                && !await FlushPendingCoreAsync(
                    CancellationToken.None,
                    publishSnapshot: true).ConfigureAwait(false))
            {
                return;
            }

            foreach (var delta in deltas.Where(delta => delta.Bytes.Total > 0))
            {
                var key = new ConnectionAttributionStorageKey(
                    localDay,
                    delta.Metadata.ApplicationName
                        ?? ConnectionAttributionLabel.UnknownApplication,
                    delta.Metadata.Hostname
                        ?? ConnectionAttributionLabel.UnknownHostname);
                _pending[key] = TrafficBytes.Add(
                    _pending.GetValueOrDefault(key, TrafficBytes.Zero),
                    delta.Bytes);
            }
            ScheduleFlushLocked();
        }
        catch (Exception exception)
        {
            PublishUnavailable(exception);
        }
        finally
        {
            _operationGate.Release();
        }
    }

    public async Task FlushPendingAsync(CancellationToken cancellationToken)
    {
        try
        {
            await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            return;
        }

        try
        {
            if (_disposed)
            {
                return;
            }
            _ = await FlushPendingCoreAsync(
                cancellationToken,
                publishSnapshot: true).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception exception)
        {
            PublishUnavailable(exception);
        }
        finally
        {
            _operationGate.Release();
        }
    }

    private async Task<bool> FlushPendingCoreAsync(
        CancellationToken cancellationToken,
        bool publishSnapshot)
    {
        _ = CancelScheduledFlushLocked();
        if (_pending.Count == 0)
        {
            return true;
        }

        var pendingSnapshot = _pending.ToArray();
        var aggregates = pendingSnapshot
            .Select(item => new ConnectionAttributionAggregate(item.Key, item.Value))
            .ToArray();
        _pending.Clear();

        ConnectionAnalyticsLedgerSnapshot snapshot;
        try
        {
            snapshot = await _ledger.RecordAsync(
                aggregates,
                _maximumPairCountPerDay,
                _timeZone,
                _timeProvider.GetUtcNow(),
                cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            RestorePending(pendingSnapshot);
            ScheduleFlushLocked();
            throw;
        }
        catch (Exception exception)
        {
            RestorePending(pendingSnapshot);
            PublishUnavailable(exception);
            return false;
        }

        if (publishSnapshot)
        {
            try
            {
                await PublishAvailableSnapshotAsync(
                    snapshot,
                    _currentState.SelectedLocalDay,
                    cancellationToken).ConfigureAwait(false);
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
        }
        return true;
    }

    private async Task FlushPendingForTrendAsync(CancellationToken cancellationToken)
    {
        _ = CancelScheduledFlushLocked();
        if (_pending.Count == 0)
        {
            return;
        }

        var pendingSnapshot = _pending.ToArray();
        var aggregates = pendingSnapshot
            .Select(item => new ConnectionAttributionAggregate(item.Key, item.Value))
            .ToArray();
        _pending.Clear();
        try
        {
            _ = await _ledger.RecordAsync(
                aggregates,
                _maximumPairCountPerDay,
                _timeZone,
                _timeProvider.GetUtcNow(),
                cancellationToken).ConfigureAwait(false);
        }
        catch
        {
            RestorePending(pendingSnapshot);
            ScheduleFlushLocked();
            throw;
        }
    }

    private void RestorePending(
        IReadOnlyList<KeyValuePair<ConnectionAttributionStorageKey, TrafficBytes>> snapshot)
    {
        foreach (var item in snapshot)
        {
            _pending[item.Key] = TrafficBytes.Add(
                _pending.GetValueOrDefault(item.Key, TrafficBytes.Zero),
                item.Value);
        }
    }

    private void ScheduleFlushLocked()
    {
        if (_flushTask is not null || _pending.Count == 0 || _disposed)
        {
            return;
        }

        _flushSource = new CancellationTokenSource();
        _flushTask = RunScheduledFlushAsync(_flushSource.Token);
    }

    private Task? CancelScheduledFlushLocked()
    {
        var task = _flushTask;
        _flushTask = null;
        var source = _flushSource;
        _flushSource = null;
        source?.Cancel();
        source?.Dispose();
        return task;
    }

    private async Task RunScheduledFlushAsync(CancellationToken cancellationToken)
    {
        try
        {
            await Task.Delay(_flushInterval, _timeProvider, cancellationToken)
                .ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            return;
        }

        await FlushPendingAsync(CancellationToken.None).ConfigureAwait(false);
    }

    private static async Task ObserveScheduledFlushAsync(Task task)
    {
        try
        {
            await task.ConfigureAwait(false);
        }
        catch (Exception)
        {
        }
    }
}
