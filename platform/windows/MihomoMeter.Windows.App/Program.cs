using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Lifecycle;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App;

internal static class Program
{
    [STAThread]
    public static async Task Main()
    {
        StartupConsoleReporter.Initialize();
        try
        {
            await RunAsync();
        }
        catch (Exception exception)
        {
            StartupConsoleReporter.Failure("program_main", exception);
            throw;
        }
    }

    private static async Task RunAsync()
    {
        StartupConsoleReporter.Stage("single_instance_registration_started");
        var instanceCoordinator = SingleInstanceCoordinator.CreateForCurrentSession();
        try
        {
            if (!instanceCoordinator.IsPrimary)
            {
                StartupConsoleReporter.Stage("single_instance_redirect_started");
                await instanceCoordinator.RedirectActivationAsync(AllowForegroundActivation);
                StartupConsoleReporter.Stage("single_instance_redirect_completed");
                return;
            }

            instanceCoordinator.StartListening(
                HandleActivationRequest,
                exception => StartupConsoleReporter.Failure(
                    "single_instance_listener",
                    exception));
            WinRT.ComWrappersSupport.InitializeComWrappers();
            StartupConsoleReporter.Stage("single_instance_primary_ready");
            ReportSharedCoreRuntimeStatus();
            SharedCoreTrafficShadow.ConfigureReporter(
                SharedCoreTrafficShadowReporter.Report);
            var previousSynchronizationContext = SynchronizationContext.Current;
            try
            {
                Application.Start(initialization =>
                {
                    var context = new DispatcherQueueSynchronizationContext(
                        DispatcherQueue.GetForCurrentThread());
                    SynchronizationContext.SetSynchronizationContext(context);
                    _ = new App();
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

    private static void HandleActivationRequest()
    {
        StartupConsoleReporter.Stage("single_instance_activation_received");
        ActivationRouter.RequestMainWindowActivation();
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
