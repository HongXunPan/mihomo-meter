using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.Windows.AppLifecycle;
using MihomoMeter.Windows.App.Application;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Lifecycle;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App;

internal static class Program
{
    [STAThread]
    public static async Task Main(string[] args)
    {
        StartupConsoleReporter.Initialize();
        try
        {
            WinRT.ComWrappersSupport.InitializeComWrappers();
            var activationArguments = AppInstance.GetCurrent().GetActivatedEventArgs();
            var isStartupLaunch = StartupActivation.IsStartupLaunch(args);
            StartupActivation.TryResolveProtocolTarget(
                activationArguments,
                out var activationTarget);
            if (isStartupLaunch)
            {
                StartupConsoleReporter.Stage("startup_activation_detected");
            }
            await RunAsync(args, isStartupLaunch, activationArguments, activationTarget);
        }
        catch (Exception exception)
        {
            StartupConsoleReporter.Failure("program_main", exception);
            throw;
        }
    }

    private static async Task RunAsync(
        IReadOnlyCollection<string> arguments,
        bool isStartupLaunch,
        AppActivationArguments? activationArguments,
        AppActivationTarget activationTarget)
    {
        StartupConsoleReporter.Stage("single_instance_registration_started");
        var instanceCoordinator = SingleInstanceCoordinator.CreateForCurrentSession();
        try
        {
            if (!instanceCoordinator.IsPrimary)
            {
                if (isStartupLaunch
                    || CrashRecoveryRestartPolicy.HasRecoveryArgument(arguments))
                {
                    StartupConsoleReporter.Stage(
                        "background_secondary_instance_skipped");
                    return;
                }

                StartupConsoleReporter.Stage("single_instance_redirect_started");
                await instanceCoordinator.RedirectActivationAsync(
                    activationTarget,
                    AllowForegroundActivation);
                StartupConsoleReporter.Stage("single_instance_redirect_completed");
                return;
            }

            var crashRecoveryRestart = new CrashRecoveryRestartCoordinator();
            var recoveryDisposition =
                crashRecoveryRestart.EvaluateStartup(arguments);
            switch (recoveryDisposition)
            {
                case CrashRecoveryStartupDisposition.RecoveryAllowed:
                    StartupConsoleReporter.Stage("crash_recovery_restart_allowed");
                    break;
                case CrashRecoveryStartupDisposition.RecoverySuppressed:
                    StartupConsoleReporter.Stage("crash_recovery_restart_suppressed");
                    return;
                case CrashRecoveryStartupDisposition.RecoveryArgumentInvalid:
                    StartupConsoleReporter.Stage(
                        "crash_recovery_restart_argument_invalid");
                    return;
            }

            instanceCoordinator.StartListening(
                HandleActivationRequest,
                exception => StartupConsoleReporter.Failure(
                    "single_instance_listener",
                    exception));
            StartupConsoleReporter.Stage("single_instance_primary_ready");
            ReportSharedCoreRuntimeStatus();
            SharedCoreProxyTypeShadow.ConfigureReporter(
                SharedCoreTrafficDiagnosticReporter.ReportProxyTypeShadow);
            SharedCoreProxyTypeRoute.ConfigureReporter(
                SharedCoreTrafficDiagnosticReporter.ReportProxyTypeRoute);
            SharedCoreTrafficShadow.ConfigureReporter(
                SharedCoreTrafficDiagnosticReporter.ReportShadow);
            SharedCoreTrafficRoute.ConfigureReporter(
                SharedCoreTrafficDiagnosticReporter.ReportRoute);
            var previousSynchronizationContext = SynchronizationContext.Current;
            try
            {
                Application.Start(initialization =>
                {
                    var context = new DispatcherQueueSynchronizationContext(
                        DispatcherQueue.GetForCurrentThread());
                    SynchronizationContext.SetSynchronizationContext(context);
                    _ = new App(
                        isStartupLaunch,
                        activationArguments,
                        crashRecoveryRestart.RegisterForCurrentProcess,
                        crashRecoveryRestart.UnregisterForExplicitExit);
                });
            }
            finally
            {
                SynchronizationContext.SetSynchronizationContext(
                    previousSynchronizationContext);
            }
        }
        finally
        {
            await instanceCoordinator.DisposeAsync().ConfigureAwait(false);
            StartupConsoleReporter.Stage("single_instance_shutdown_completed");
        }
    }

    private static void HandleActivationRequest(AppActivationTarget target)
    {
        StartupConsoleReporter.Stage("single_instance_activation_received");
        ActivationRouter.RequestActivation(target);
    }

    private static void ReportSharedCoreRuntimeStatus()
    {
        var status = SharedCoreRuntimeProbe.Run();
        var stage = status switch
        {
            SharedCoreRuntimeStatus.Ready => "shared_core_runtime_ready",
            SharedCoreRuntimeStatus.AbiMismatch => "shared_core_runtime_abi_mismatch",
            SharedCoreRuntimeStatus.NativeCallFailed => "shared_core_runtime_native_call_failed",
            SharedCoreRuntimeStatus.UnexpectedResult => "shared_core_runtime_unexpected_result",
            _ => "shared_core_runtime_unknown_failure",
        };
        StartupConsoleReporter.Stage(stage);
    }

    private static void AllowForegroundActivation(uint processId)
    {
        if (!ShellNativeMethods.AllowSetForegroundWindow(processId))
        {
            StartupConsoleReporter.Stage("single_instance_foreground_handoff_unavailable");
        }
    }
}
