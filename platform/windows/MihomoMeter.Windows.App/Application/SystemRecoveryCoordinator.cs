using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Infrastructure.System;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Application;

internal sealed class SystemRecoveryCoordinator : IAsyncDisposable
{
    private readonly TrafficMonitoringCoordinator _traffic;
    private readonly WindowsSystemEnvironmentMonitor _environmentMonitor;
    private readonly SystemRecoveryPolicy _policy = new();
    private readonly object _sync = new();
    private Task _pendingTransition = Task.CompletedTask;
    private bool _started;
    private bool _disposed;

    public SystemRecoveryCoordinator(
        TrafficMonitoringCoordinator traffic,
        WindowsSystemEnvironmentMonitor environmentMonitor)
    {
        _traffic = traffic;
        _environmentMonitor = environmentMonitor;
    }

    public async Task StartAsync()
    {
        if (_started || _disposed)
        {
            return;
        }

        _environmentMonitor.EnvironmentChanged += EnvironmentMonitor_EnvironmentChanged;
        try
        {
            var sessionMonitoringAvailable = _environmentMonitor.Start();
            if (!sessionMonitoringAvailable)
            {
                StartupConsoleReporter.Failure(
                    "system_recovery_session_monitor",
                    new InvalidOperationException("Windows 会话状态监听不可用。"));
            }
            _started = true;
            Task pendingTransition;
            lock (_sync)
            {
                pendingTransition = _pendingTransition;
            }
            await pendingTransition.ConfigureAwait(false);
        }
        catch (Exception exception)
        {
            _environmentMonitor.EnvironmentChanged -= EnvironmentMonitor_EnvironmentChanged;
            StartupConsoleReporter.Failure("system_recovery_monitor", exception);
        }
    }

    public async ValueTask DisposeAsync()
    {
        Task pendingTransition;
        lock (_sync)
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;
            _environmentMonitor.EnvironmentChanged -= EnvironmentMonitor_EnvironmentChanged;
            _environmentMonitor.Dispose();
            pendingTransition = _pendingTransition;
        }
        await pendingTransition.ConfigureAwait(false);
    }

    private void EnvironmentMonitor_EnvironmentChanged(
        SystemEnvironmentBlocker blocker,
        bool isBlocked)
    {
        lock (_sync)
        {
            if (_disposed)
            {
                return;
            }

            var action = _policy.Update(blocker, isBlocked);
            if (action is null)
            {
                return;
            }

            var isAvailable = action == SystemRecoveryAction.Resume;
            _pendingTransition = _pendingTransition.ContinueWith(
                _ => ApplyAvailabilityAsync(isAvailable),
                CancellationToken.None,
                TaskContinuationOptions.ExecuteSynchronously,
                TaskScheduler.Default).Unwrap();
        }
    }

    private async Task ApplyAvailabilityAsync(bool isAvailable)
    {
        try
        {
            await _traffic
                .SetSystemEnvironmentAvailableAsync(isAvailable)
                .ConfigureAwait(false);
        }
        catch (Exception exception)
        {
            StartupConsoleReporter.Failure("system_recovery_transition", exception);
        }
    }
}
