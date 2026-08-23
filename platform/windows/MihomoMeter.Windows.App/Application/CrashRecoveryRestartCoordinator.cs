using System.Runtime.InteropServices;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Infrastructure.Recovery;
using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Application;

internal sealed class CrashRecoveryRestartCoordinator
{
    private readonly object _gate = new();
    private readonly JsonCrashRecoveryRestartStateStore _stateStore;
    private readonly TimeProvider _timeProvider;
    private CrashRecoveryRestartState _state = CrashRecoveryRestartState.Empty;
    private Timer? _registrationTimer;
    private bool _evaluated;
    private bool _registrationDisabled;
    private bool _registered;
    private bool _explicitExit;

    public CrashRecoveryRestartCoordinator(
        JsonCrashRecoveryRestartStateStore? stateStore = null,
        TimeProvider? timeProvider = null)
    {
        _stateStore = stateStore ?? new JsonCrashRecoveryRestartStateStore();
        _timeProvider = timeProvider ?? TimeProvider.System;
    }

    public CrashRecoveryStartupDisposition EvaluateStartup(
        IEnumerable<string> arguments)
    {
        ArgumentNullException.ThrowIfNull(arguments);
        var argumentSnapshot = arguments.ToArray();
        var hasRecoveryArgument =
            CrashRecoveryRestartPolicy.HasRecoveryArgument(argumentSnapshot);

        lock (_gate)
        {
            if (_evaluated)
            {
                throw new InvalidOperationException("恢复重启启动参数已经完成判定。");
            }

            _evaluated = true;
            try
            {
                _state = _stateStore.Load();
                var decision = CrashRecoveryRestartPolicy.EvaluateStartup(
                    argumentSnapshot,
                    _state,
                    _timeProvider.GetUtcNow());
                if (decision.State != _state)
                {
                    _stateStore.Save(decision.State);
                }

                _state = decision.State;
                return decision.Disposition;
            }
            catch (Exception exception) when (
                exception is CrashRecoveryRestartStateStorageException
                    or IOException
                    or UnauthorizedAccessException)
            {
                _registrationDisabled = true;
                StartupConsoleReporter.Failure(
                    "crash_recovery_state",
                    exception);
                return hasRecoveryArgument
                    ? CrashRecoveryStartupDisposition.RecoveryArgumentInvalid
                    : CrashRecoveryStartupDisposition.RegularLaunch;
            }
        }
    }

    public void RegisterForCurrentProcess()
    {
        lock (_gate)
        {
            if (!_evaluated)
            {
                throw new InvalidOperationException("必须先判定恢复重启启动参数。");
            }

            if (_registrationDisabled
                || _registered
                || _explicitExit
                || _registrationTimer is not null)
            {
                return;
            }

            var delay = CrashRecoveryRestartPolicy.RegistrationDelay(
                _state,
                _timeProvider.GetUtcNow());
            if (delay > TimeSpan.Zero)
            {
                _registrationTimer = new Timer(
                    static state =>
                        ((CrashRecoveryRestartCoordinator)state!).RegisterNow(),
                    this,
                    delay,
                    Timeout.InfiniteTimeSpan);
                StartupConsoleReporter.Stage("crash_recovery_registration_delayed");
                return;
            }
        }

        RegisterNow();
    }

    public void UnregisterForExplicitExit()
    {
        lock (_gate)
        {
            if (_explicitExit)
            {
                return;
            }

            _explicitExit = true;
            _registrationTimer?.Dispose();
            _registrationTimer = null;
            if (_registered)
            {
                var result = ApplicationRestartNativeMethods
                    .UnregisterApplicationRestart();
                if (result < 0)
                {
                    ReportHResult("crash_recovery_unregister", result);
                }

                _registered = false;
            }

            ClearPendingRegistration();
            StartupConsoleReporter.Stage("crash_recovery_unregistered_for_exit");
        }
    }

    private void RegisterNow()
    {
        lock (_gate)
        {
            _registrationTimer?.Dispose();
            _registrationTimer = null;
            if (_registrationDisabled || _registered || _explicitExit)
            {
                return;
            }

            var token = Guid.NewGuid().ToString("N");
            var preparedState = CrashRecoveryRestartPolicy.PrepareRegistration(
                _state,
                _timeProvider.GetUtcNow(),
                token);
            try
            {
                _stateStore.Save(preparedState);
            }
            catch (CrashRecoveryRestartStateStorageException exception)
            {
                _registrationDisabled = true;
                StartupConsoleReporter.Failure(
                    "crash_recovery_state_save",
                    exception);
                return;
            }

            _state = preparedState;
            var commandLineArguments =
                $"{CrashRecoveryRestartPolicy.RecoveryArgumentPrefix}{token}";
            var result = ApplicationRestartNativeMethods.RegisterApplicationRestart(
                commandLineArguments,
                ApplicationRestartFlags.NoPatch | ApplicationRestartFlags.NoReboot);
            if (result < 0)
            {
                _registrationDisabled = true;
                ClearPendingRegistration();
                ReportHResult("crash_recovery_register", result);
                return;
            }

            _registered = true;
            StartupConsoleReporter.Stage("crash_recovery_registered");
        }
    }

    private void ClearPendingRegistration()
    {
        if (_state.PendingToken is null && _state.PendingRegisteredAtUtc is null)
        {
            return;
        }

        var clearedState = _state with
        {
            PendingToken = null,
            PendingRegisteredAtUtc = null,
        };
        try
        {
            _stateStore.Save(clearedState);
            _state = clearedState;
        }
        catch (CrashRecoveryRestartStateStorageException exception)
        {
            StartupConsoleReporter.Failure(
                "crash_recovery_state_clear",
                exception);
        }
    }

    private static void ReportHResult(string source, int hresult)
    {
        StartupConsoleReporter.Failure(
            source,
            new COMException("Windows 恢复重启注册调用失败。", hresult));
    }
}
