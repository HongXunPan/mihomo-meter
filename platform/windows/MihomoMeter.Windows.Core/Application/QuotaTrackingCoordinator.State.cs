using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public sealed partial class QuotaTrackingCoordinator
{
    private async Task ExecuteOperationAsync(
        Func<Task> operation,
        CancellationToken cancellationToken)
    {
        await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            _operationInProgress = true;
            Publish(_currentState.Availability);
            await operation().ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (OperationCanceledException)
        {
            _message = "订阅配额网络操作已停止。";
            Publish(QuotaAvailability.Available);
        }
        catch (Exception exception) when (
            exception is QuotaLedgerException
                or QuotaDomainException
                or ProfileDirectoryException
                or ActiveQuotaQueryException
                or IOException
                or UnauthorizedAccessException)
        {
            if (exception is QuotaLedgerException)
            {
                _ledgerAvailable = false;
            }

            _message = SafeMessage(exception);
            Publish(exception is QuotaLedgerException
                ? QuotaAvailability.Unavailable
                : QuotaAvailability.Available);
        }
        catch (Exception)
        {
            _message = "订阅配额操作失败。";
            Publish(QuotaAvailability.Available);
        }
        finally
        {
            _operationInProgress = false;
            Publish(_currentState.Availability);
            _operationGate.Release();
        }
    }

    private void Publish(QuotaAvailability availability)
    {
        var effectiveAvailability = (
            !_ledgerAvailable
            && availability != QuotaAvailability.Loading)
                ? QuotaAvailability.Unavailable
                : availability;
        var state = new QuotaTrackingState(
            effectiveAvailability,
            _ledgerSnapshot,
            _catalog,
            _profileDirectoryPath,
            _runtimeStatus,
            _runtimeCandidateCount,
            _endpoint is not null,
            _endpoint is not null && _runtimeConfiguration?.Proxy is not null,
            _operationInProgress,
            _message);
        Action<QuotaTrackingState>? handler;
        lock (_stateLock)
        {
            _currentState = state;
            handler = StateChanged;
        }

        handler?.Invoke(state);
    }

    private async Task StopNetworkTasksAsync()
    {
        CancellationTokenSource? source;
        lock (_networkSourceLock)
        {
            source = _networkSource;
            _networkSource = null;
        }

        var runtimeTask = _runtimeTask;
        var queryTask = _queryScheduleTask;
        _runtimeTask = null;
        _queryScheduleTask = null;
        if (source is null)
        {
            return;
        }

        source.Cancel();
        await ObserveCancellationAsync(runtimeTask).ConfigureAwait(false);
        await ObserveCancellationAsync(queryTask).ConfigureAwait(false);
        source.Dispose();
    }

    private CancellationTokenSource CreateNetworkQuerySource(
        CancellationToken cancellationToken)
    {
        lock (_networkSourceLock)
        {
            if (_networkSource is null)
            {
                var unavailableSource = CancellationTokenSource
                    .CreateLinkedTokenSource(cancellationToken);
                unavailableSource.Cancel();
                return unavailableSource;
            }

            return CancellationTokenSource.CreateLinkedTokenSource(
                cancellationToken,
                _networkSource.Token);
        }
    }

    private static async Task ObserveCancellationAsync(Task? task)
    {
        if (task is null)
        {
            return;
        }

        try
        {
            await task.ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
        }
    }

    private static string SafeMessage(Exception exception)
    {
        return exception switch
        {
            ActiveQuotaQueryException query => query.Message,
            ProfileDirectoryException profile => profile.Message,
            QuotaLedgerException ledger => ledger.Message,
            QuotaDomainException domain => domain.Message,
            _ => "订阅配额操作失败。",
        };
    }
}
