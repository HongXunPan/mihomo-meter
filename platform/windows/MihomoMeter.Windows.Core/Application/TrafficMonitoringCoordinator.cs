using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Core.Application;

public sealed partial class TrafficMonitoringCoordinator : IAsyncDisposable
{
    private readonly IMihomoControllerClient _client;
    private readonly IControllerConfigurationStore _configurationStore;
    private readonly TrafficMonitoringStream _stream;
    private readonly ITrafficStatisticsRecorder _statisticsRecorder;
    private readonly IQuotaTrackingLifecycle _quotaTrackingLifecycle;
    private readonly IDiagnosticEventSink _diagnosticEventSink;
    private readonly TimeProvider _timeProvider;
    private readonly SemaphoreSlim _transitionLock = new(1, 1);
    private readonly object _stateLock = new();
    private CancellationTokenSource? _runSource;
    private Task? _runTask;
    private long _generation;
    private int _connectionExpected;
    private int _hasValidatedConfiguration;
    private int _systemEnvironmentAvailable = 1;
    private int _systemRecoveryEligible;

    public TrafficMonitoringCoordinator(
        IMihomoControllerClient client,
        IConnectionSnapshotCollector collector,
        IControllerConfigurationStore configurationStore,
        MonitoringPolicy? policy = null,
        TimeProvider? timeProvider = null,
        ITrafficStatisticsRecorder? statisticsRecorder = null,
        IQuotaTrackingLifecycle? quotaTrackingLifecycle = null,
        IConnectionAnalyticsRecorder? connectionAnalyticsRecorder = null,
        IDiagnosticEventSink? diagnosticEventSink = null)
    {
        var selectedPolicy = (policy ?? MonitoringPolicy.Production).Validate();
        _client = client;
        _configurationStore = configurationStore;
        _timeProvider = timeProvider ?? TimeProvider.System;
        _statisticsRecorder = statisticsRecorder ?? NullTrafficStatisticsRecorder.Instance;
        _diagnosticEventSink = diagnosticEventSink ?? NullDiagnosticEventSink.Instance;
        var analyticsRecorder = new FaultIsolatedConnectionAnalyticsRecorder(
            connectionAnalyticsRecorder ?? NullConnectionAnalyticsRecorder.Instance);
        _quotaTrackingLifecycle = new FaultIsolatedQuotaTrackingLifecycle(
            quotaTrackingLifecycle ?? NullQuotaTrackingLifecycle.Instance);
        _stream = new TrafficMonitoringStream(
            client,
            collector,
            selectedPolicy,
            _timeProvider,
            _statisticsRecorder,
            analyticsRecorder,
            _diagnosticEventSink);
    }

    public event Action<TrafficMonitorSnapshot>? SnapshotChanged;

    public bool IsConnectionExpected => Volatile.Read(ref _connectionExpected) == 1;

    public bool HasValidatedConfiguration => Volatile.Read(ref _hasValidatedConfiguration) == 1;

    public bool IsSystemEnvironmentAvailable =>
        Volatile.Read(ref _systemEnvironmentAvailable) == 1;

    public bool IsCurrentSession(long sessionGeneration)
    {
        return sessionGeneration == Volatile.Read(ref _generation);
    }

    public async Task StartAsync(
        string address,
        string secret,
        bool saveValidatedConfiguration,
        CancellationToken cancellationToken = default)
    {
        Volatile.Write(ref _connectionExpected, 1);
        Volatile.Write(ref _hasValidatedConfiguration, saveValidatedConfiguration ? 0 : 1);
        Volatile.Write(ref _systemRecoveryEligible, saveValidatedConfiguration ? 0 : 1);
        await _transitionLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            _ = Interlocked.Increment(ref _generation);
            await StopActiveRunAsync().ConfigureAwait(false);
            if (!IsSystemEnvironmentAvailable)
            {
                var generation = Interlocked.Increment(ref _generation);
                if (saveValidatedConfiguration)
                {
                    Volatile.Write(ref _connectionExpected, 0);
                }
                Publish(generation, new TrafficMonitorSnapshot(
                    MonitorConnectionState.Disconnected,
                    "系统环境暂不可用，已暂停连接。"));
                return;
            }

            StartRun(address, secret, saveValidatedConfiguration);
        }
        finally
        {
            _transitionLock.Release();
        }
    }

    public async Task StopAsync(CancellationToken cancellationToken = default)
    {
        Volatile.Write(ref _connectionExpected, 0);
        Volatile.Write(ref _systemRecoveryEligible, 0);
        await StopAsync(TrafficSessionEndReason.MonitoringStopped, cancellationToken)
            .ConfigureAwait(false);
    }

    private async Task StopAsync(
        TrafficSessionEndReason reason,
        CancellationToken cancellationToken)
    {
        await _transitionLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var generation = Interlocked.Increment(ref _generation);
            await StopActiveRunAsync().ConfigureAwait(false);
            await _quotaTrackingLifecycle
                .ControllerUnavailableAsync(cancellationToken)
                .ConfigureAwait(false);
            await _statisticsRecorder
                .InterruptMonitoringAsync(reason, cancellationToken)
                .ConfigureAwait(false);
            Publish(generation, TrafficMonitorSnapshot.Disconnected);
            _diagnosticEventSink.Record(DiagnosticExportEvent.ConnectionStopped(
                _timeProvider.GetUtcNow(),
                EndReason(reason)));
        }
        finally
        {
            _transitionLock.Release();
        }
    }

    public async ValueTask DisposeAsync()
    {
        Volatile.Write(ref _connectionExpected, 0);
        Volatile.Write(ref _systemRecoveryEligible, 0);
        await StopAsync(TrafficSessionEndReason.ApplicationExit, CancellationToken.None)
            .ConfigureAwait(false);
        _transitionLock.Dispose();
    }

    private async Task RunAsync(
        long generation,
        string address,
        string secret,
        bool saveValidatedConfiguration,
        CancellationToken cancellationToken)
    {
        ControllerEndpoint endpoint;
        try
        {
            endpoint = new ControllerEndpoint(address);
        }
        catch (ControllerEndpointException exception)
        {
            Volatile.Write(ref _systemRecoveryEligible, 0);
            Publish(generation, new TrafficMonitorSnapshot(
                MonitorConnectionState.Disconnected,
                exception.Message));
            return;
        }

        var backoff = new ReconnectBackoff();
        var shouldSaveConfiguration = saveValidatedConfiguration;
        var isFirstAttempt = true;
        var attemptNumber = 0;

        while (!cancellationToken.IsCancellationRequested)
        {
            attemptNumber += 1;
            _diagnosticEventSink.Record(DiagnosticExportEvent.ConnectionAttemptStarted(
                _timeProvider.GetUtcNow(),
                isFirstAttempt
                    ? saveValidatedConfiguration ? "user_request" : "application_startup"
                    : "automatic_retry",
                attemptNumber));
            Publish(generation, new TrafficMonitorSnapshot(
                isFirstAttempt
                    ? MonitorConnectionState.Connecting
                    : MonitorConnectionState.Reconnecting,
                isFirstAttempt ? "正在验证 Mihomo Controller。" : "正在重新连接 Mihomo。"));

            try
            {
                var version = await _client
                    .FetchVersionAsync(endpoint, secret, cancellationToken)
                    .ConfigureAwait(false);
                var proxies = await _client
                    .FetchProxiesAsync(endpoint, secret, cancellationToken)
                    .ConfigureAwait(false);
                var runtimeConfiguration = await TryFetchRuntimeConfigurationAsync(
                    endpoint,
                    secret,
                    cancellationToken).ConfigureAwait(false);

                if (shouldSaveConfiguration)
                {
                    await _configurationStore
                        .SaveValidatedAsync(endpoint, secret, cancellationToken)
                        .ConfigureAwait(false);
                    shouldSaveConfiguration = false;
                    Volatile.Write(ref _hasValidatedConfiguration, 1);
                }

                await _statisticsRecorder
                    .BeginMonitoringAsync(version.Version, cancellationToken)
                    .ConfigureAwait(false);
                await _quotaTrackingLifecycle
                    .ControllerValidatedAsync(endpoint, secret, cancellationToken)
                    .ConfigureAwait(false);

                await _stream.RunAsync(
                    endpoint,
                    secret,
                    version.Version,
                    proxies.ToCatalog(),
                    runtimeConfiguration,
                    snapshot => Publish(generation, snapshot),
                    cancellationToken).ConfigureAwait(false);
                throw new ConnectionStreamException(ConnectionStreamError.Closed);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                return;
            }
            catch (MonitoringStreamException exception)
            {
                if (exception.WasStable)
                {
                    backoff.Reset();
                }

                if (PublishTerminalIfNeeded(generation, exception.RootException))
                {
                    RecordTerminalStop(exception.RootException);
                    await _quotaTrackingLifecycle
                        .ControllerUnavailableAsync(CancellationToken.None)
                        .ConfigureAwait(false);
                    await _statisticsRecorder
                        .InterruptMonitoringAsync(
                            TrafficSessionEndReason.TerminalFailure,
                            CancellationToken.None)
                        .ConfigureAwait(false);
                    return;
                }

                await _quotaTrackingLifecycle
                    .ControllerUnavailableAsync(CancellationToken.None)
                    .ConfigureAwait(false);
                await WaitForRetryAsync(
                    generation,
                    backoff,
                    exception.RootException,
                    cancellationToken).ConfigureAwait(false);
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                if (PublishTerminalIfNeeded(generation, exception))
                {
                    RecordTerminalStop(exception);
                    await _quotaTrackingLifecycle
                        .ControllerUnavailableAsync(CancellationToken.None)
                        .ConfigureAwait(false);
                    await _statisticsRecorder
                        .InterruptMonitoringAsync(
                            TrafficSessionEndReason.TerminalFailure,
                            CancellationToken.None)
                        .ConfigureAwait(false);
                    return;
                }

                await _quotaTrackingLifecycle
                    .ControllerUnavailableAsync(CancellationToken.None)
                    .ConfigureAwait(false);
                await WaitForRetryAsync(
                    generation,
                    backoff,
                    exception,
                    cancellationToken).ConfigureAwait(false);
            }

            isFirstAttempt = false;
        }
    }

    private async Task WaitForRetryAsync(
        long generation,
        ReconnectBackoff backoff,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var delaySeconds = backoff.NextDelaySeconds();
        _diagnosticEventSink.Record(DiagnosticExportEvent.ConnectionReconnectScheduled(
            _timeProvider.GetUtcNow(),
            DiagnosticReason(exception),
            delaySeconds));
        Publish(generation, new TrafficMonitorSnapshot(
            MonitorConnectionState.Reconnecting,
            $"{exception.Message} 将在 {delaySeconds} 秒后重试。"));
        try
        {
            await Task.Delay(
                TimeSpan.FromSeconds(delaySeconds),
                _timeProvider,
                cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
    }

    private async Task<MihomoRuntimeConfiguration?> TryFetchRuntimeConfigurationAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken)
    {
        try
        {
            var configuration = await _client
                .FetchRuntimeConfigurationAsync(endpoint, secret, cancellationToken)
                .ConfigureAwait(false);
            return configuration.ToRuntimeConfiguration();
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            _diagnosticEventSink.Record(
                DiagnosticExportEvent.RuntimeConfigurationUnavailable(
                    _timeProvider.GetUtcNow(),
                    DiagnosticReason(exception)));
            return null;
        }
    }

    private bool PublishTerminalIfNeeded(long generation, Exception exception)
    {
        if (exception is MihomoControllerException controllerException)
        {
            if (controllerException.Reason == MihomoControllerError.AuthenticationFailed)
            {
                Volatile.Write(ref _systemRecoveryEligible, 0);
                Publish(generation, new TrafficMonitorSnapshot(
                    MonitorConnectionState.AuthenticationFailed,
                    controllerException.Message));
                return true;
            }

            if (controllerException.Reason == MihomoControllerError.UnsupportedResponse)
            {
                Volatile.Write(ref _systemRecoveryEligible, 0);
                Publish(generation, new TrafficMonitorSnapshot(
                    MonitorConnectionState.Unsupported,
                    controllerException.Message));
                return true;
            }
        }

        if (exception is ConnectionStreamException streamException
            && streamException.Reason
                is ConnectionStreamError.UnsupportedResponse or ConnectionStreamError.MessageTooLarge)
        {
            Volatile.Write(ref _systemRecoveryEligible, 0);
            Publish(generation, new TrafficMonitorSnapshot(
                MonitorConnectionState.Unsupported,
                streamException.Message));
            return true;
        }

        if (exception is ControllerConfigurationException)
        {
            Volatile.Write(ref _systemRecoveryEligible, 0);
            Publish(generation, new TrafficMonitorSnapshot(
                MonitorConnectionState.Disconnected,
                exception.Message));
            return true;
        }

        return false;
    }

    private void RecordTerminalStop(Exception exception)
    {
        _diagnosticEventSink.Record(DiagnosticExportEvent.ConnectionStopped(
            _timeProvider.GetUtcNow(),
            DiagnosticReason(exception)));
    }

    private static string DiagnosticReason(Exception exception)
    {
        return exception switch
        {
            MihomoControllerException { Reason: MihomoControllerError.AuthenticationFailed } =>
                "authentication_failed",
            MihomoControllerException { Reason: MihomoControllerError.UnsupportedResponse } =>
                "unsupported_response",
            MihomoControllerException { Reason: MihomoControllerError.HttpStatus } =>
                "controller_http",
            MihomoControllerException { Reason: MihomoControllerError.Network } =>
                "controller_network",
            MihomoControllerException { Reason: MihomoControllerError.Timeout } =>
                "controller_timeout",
            ConnectionStreamException { Reason: ConnectionStreamError.Closed } =>
                "stream_closed",
            ConnectionStreamException { Reason: ConnectionStreamError.Network } =>
                "stream_network",
            ConnectionStreamException { Reason: ConnectionStreamError.Timeout } =>
                "stream_timeout",
            ConnectionStreamException { Reason: ConnectionStreamError.DataStale } =>
                "data_stale",
            ConnectionStreamException => "unsupported_response",
            ControllerConfigurationException => "configuration_failure",
            _ => "unknown",
        };
    }

    private static string EndReason(TrafficSessionEndReason reason)
    {
        return reason switch
        {
            TrafficSessionEndReason.MonitoringStopped => "monitoring_stopped",
            TrafficSessionEndReason.ApplicationExit => "application_exit",
            TrafficSessionEndReason.TerminalFailure => "terminal_failure",
            _ => "unknown",
        };
    }

    private async Task StopActiveRunAsync()
    {
        var source = _runSource;
        var task = _runTask;
        _runSource = null;
        _runTask = null;

        if (source is null)
        {
            return;
        }

        source.Cancel();
        if (task is not null)
        {
            await task.ConfigureAwait(false);
        }

        source.Dispose();
    }

    private void Publish(long generation, TrafficMonitorSnapshot snapshot)
    {
        Action<TrafficMonitorSnapshot>? handler;
        lock (_stateLock)
        {
            if (generation != Volatile.Read(ref _generation))
            {
                return;
            }

            handler = SnapshotChanged;
        }

        handler?.Invoke(snapshot with { SessionGeneration = generation });
    }
}

internal sealed class NullQuotaTrackingLifecycle : IQuotaTrackingLifecycle
{
    public static NullQuotaTrackingLifecycle Instance { get; } = new();

    public Task ControllerValidatedAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }

    public Task ControllerUnavailableAsync(CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }
}
