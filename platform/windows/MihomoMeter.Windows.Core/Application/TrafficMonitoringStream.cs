using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Core.Application;

internal sealed class TrafficMonitoringStream
{
    private readonly IMihomoControllerClient _client;
    private readonly IConnectionSnapshotCollector _collector;
    private readonly MonitoringPolicy _policy;
    private readonly TimeProvider _timeProvider;
    private readonly ITrafficStatisticsRecorder _statisticsRecorder;

    public TrafficMonitoringStream(
        IMihomoControllerClient client,
        IConnectionSnapshotCollector collector,
        MonitoringPolicy policy,
        TimeProvider timeProvider,
        ITrafficStatisticsRecorder statisticsRecorder)
    {
        _client = client;
        _collector = collector;
        _policy = policy;
        _timeProvider = timeProvider;
        _statisticsRecorder = statisticsRecorder;
    }

    public async Task RunAsync(
        ControllerEndpoint endpoint,
        string secret,
        string version,
        ProxyCatalog catalog,
        Action<TrafficMonitorSnapshot> publish,
        CancellationToken cancellationToken)
    {
        using var streamSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        await using var enumerator = _collector
            .CollectAsync(endpoint, secret, streamSource.Token)
            .GetAsyncEnumerator(streamSource.Token);
        var measurement = new TrafficMeasurementSession(catalog, _timeProvider);
        var display = new TrafficRateDisplayState();
        Task<MihomoProxiesResponse>? catalogRefreshTask = null;
        Task<bool>? moveNextTask = null;
        long? connectedAt = null;
        var stablePeriodReached = false;

        try
        {
            moveNextTask = enumerator.MoveNextAsync().AsTask();
            while (!cancellationToken.IsCancellationRequested)
            {
                var nextSnapshot = await WaitForNextSnapshotAsync(
                    moveNextTask,
                    measurement,
                    version,
                    publish,
                    streamSource,
                    cancellationToken).ConfigureAwait(false);
                if (nextSnapshot.WasStale)
                {
                    connectedAt = null;
                    display.Clear();
                }

                if (!nextSnapshot.HasNext)
                {
                    throw new ConnectionStreamException(ConnectionStreamError.Closed);
                }

                if (catalogRefreshTask?.IsCompleted == true)
                {
                    ApplyCatalogRefresh(catalogRefreshTask, measurement);
                    catalogRefreshTask = null;
                }

                var result = measurement.Consume(enumerator.Current);
                await _statisticsRecorder
                    .RecordAsync(result.LedgerObservation, cancellationToken)
                    .ConfigureAwait(false);
                display.Apply(result);
                var snapshotTimestamp = _timeProvider.GetTimestamp();
                connectedAt ??= snapshotTimestamp;
                stablePeriodReached |= _timeProvider.GetElapsedTime(
                    connectedAt.Value,
                    snapshotTimestamp) >= _policy.BackoffResetAfter;
                publish(new TrafficMonitorSnapshot(
                    MonitorConnectionState.Connected,
                    result.CountersReset ? "Mihomo 计数器已重置，正在重建基线。" : "实时监控已连接。",
                    version,
                    display.Rates,
                    display.Coverage,
                    AttributionCoverage: result.AttributionCoverage));

                if (result.RequiresCatalogRefresh && catalogRefreshTask is null)
                {
                    catalogRefreshTask = _client.FetchProxiesAsync(
                        endpoint,
                        secret,
                        streamSource.Token);
                }

                moveNextTask = enumerator.MoveNextAsync().AsTask();
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception) when (exception is not MonitoringStreamException)
        {
            throw new MonitoringStreamException(exception, stablePeriodReached);
        }
        finally
        {
            streamSource.Cancel();
            if (moveNextTask is not null)
            {
                await ObserveCancelledMoveAsync(moveNextTask).ConfigureAwait(false);
            }

            if (catalogRefreshTask is not null)
            {
                await ObserveCatalogRefreshAsync(catalogRefreshTask).ConfigureAwait(false);
            }
        }
    }

    private async Task<NextSnapshotResult> WaitForNextSnapshotAsync(
        Task<bool> moveNextTask,
        TrafficMeasurementSession measurement,
        string version,
        Action<TrafficMonitorSnapshot> publish,
        CancellationTokenSource streamSource,
        CancellationToken cancellationToken)
    {
        try
        {
            var hasNext = await moveNextTask.WaitAsync(
                _policy.StaleAfter,
                _timeProvider,
                cancellationToken).ConfigureAwait(false);
            return new NextSnapshotResult(hasNext, false);
        }
        catch (TimeoutException)
        {
            measurement.ResetBaseline();
            publish(new TrafficMonitorSnapshot(
                MonitorConnectionState.Stale,
                "实时数据已超时，正在等待恢复。",
                version));
        }

        try
        {
            var hasNext = await moveNextTask.WaitAsync(
                _policy.ReconnectAfter - _policy.StaleAfter,
                _timeProvider,
                cancellationToken).ConfigureAwait(false);
            return new NextSnapshotResult(hasNext, true);
        }
        catch (TimeoutException)
        {
            streamSource.Cancel();
            await ObserveCancelledMoveAsync(moveNextTask).ConfigureAwait(false);
            throw new ConnectionStreamException(ConnectionStreamError.DataStale);
        }
    }

    private readonly record struct NextSnapshotResult(bool HasNext, bool WasStale);

    private static void ApplyCatalogRefresh(
        Task<MihomoProxiesResponse> task,
        TrafficMeasurementSession measurement)
    {
        if (task.IsCompletedSuccessfully)
        {
            measurement.UpdateCatalog(task.Result.ToCatalog());
            return;
        }

        _ = task.Exception;
    }

    private static async Task ObserveCancelledMoveAsync(Task<bool> task)
    {
        try
        {
            _ = await task.ConfigureAwait(false);
        }
        catch (Exception)
        {
        }
    }

    private static async Task ObserveCatalogRefreshAsync(Task<MihomoProxiesResponse> task)
    {
        try
        {
            _ = await task.ConfigureAwait(false);
        }
        catch (Exception)
        {
        }
    }
}

internal sealed class MonitoringStreamException : Exception
{
    public MonitoringStreamException(Exception rootException, bool wasStable)
        : base(rootException.Message, rootException)
    {
        RootException = rootException;
        WasStable = wasStable;
    }

    public Exception RootException { get; }

    public bool WasStable { get; }
}
