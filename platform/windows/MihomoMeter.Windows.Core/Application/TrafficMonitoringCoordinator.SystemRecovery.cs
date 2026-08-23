using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public sealed partial class TrafficMonitoringCoordinator
{
    public async Task SetSystemEnvironmentAvailableAsync(
        bool isAvailable,
        CancellationToken cancellationToken = default)
    {
        await _transitionLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (IsSystemEnvironmentAvailable == isAvailable)
            {
                return;
            }

            Volatile.Write(ref _systemEnvironmentAvailable, isAvailable ? 1 : 0);
            if (!IsConnectionExpected || Volatile.Read(ref _systemRecoveryEligible) == 0)
            {
                return;
            }

            if (!isAvailable)
            {
                await PauseForSystemRecoveryAsync(cancellationToken).ConfigureAwait(false);
                return;
            }

            await ResumeAfterSystemRecoveryAsync(cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _transitionLock.Release();
        }
    }

    private async Task PauseForSystemRecoveryAsync(CancellationToken cancellationToken)
    {
        var generation = Interlocked.Increment(ref _generation);
        await StopActiveRunAsync().ConfigureAwait(false);
        await _quotaTrackingLifecycle
            .ControllerUnavailableAsync(cancellationToken)
            .ConfigureAwait(false);
        await _statisticsRecorder
            .InterruptMonitoringAsync(TrafficSessionEndReason.Recovery, cancellationToken)
            .ConfigureAwait(false);
        Publish(generation, new TrafficMonitorSnapshot(
            MonitorConnectionState.Disconnected,
            "系统休眠、会话或网络不可用，已暂停连接。"));
    }

    private async Task ResumeAfterSystemRecoveryAsync(CancellationToken cancellationToken)
    {
        if (!HasValidatedConfiguration)
        {
            return;
        }

        ControllerConfiguration configuration;
        try
        {
            configuration = await _configurationStore
                .LoadAsync(cancellationToken)
                .ConfigureAwait(false);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            Volatile.Write(ref _connectionExpected, 0);
            Volatile.Write(ref _hasValidatedConfiguration, 0);
            PublishRecoveryFailure("无法读取已验证的 Controller 配置，恢复已停止。");
            return;
        }

        if (configuration.Address.Length == 0)
        {
            Volatile.Write(ref _connectionExpected, 0);
            Volatile.Write(ref _hasValidatedConfiguration, 0);
            PublishRecoveryFailure("已验证的 Controller 配置不存在，恢复已停止。");
            return;
        }

        _ = Interlocked.Increment(ref _generation);
        await StopActiveRunAsync().ConfigureAwait(false);
        StartRun(configuration.Address, configuration.Secret, false);
    }

    private void StartRun(
        string address,
        string secret,
        bool saveValidatedConfiguration)
    {
        var runSource = new CancellationTokenSource();
        var generation = Interlocked.Increment(ref _generation);
        _runSource = runSource;
        Volatile.Write(ref _systemRecoveryEligible, 1);
        _runTask = RunAsync(
            generation,
            address,
            secret,
            saveValidatedConfiguration,
            runSource.Token);
    }

    private void PublishRecoveryFailure(string message)
    {
        var generation = Interlocked.Increment(ref _generation);
        Publish(generation, new TrafficMonitorSnapshot(
            MonitorConnectionState.Disconnected,
            message));
    }
}
