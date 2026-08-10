using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Lifecycle;

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
        await using var instanceCoordinator =
            SingleInstanceCoordinator.CreateForCurrentSession();
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
        Application.Start(initialization =>
        {
            var context = new DispatcherQueueSynchronizationContext(
                DispatcherQueue.GetForCurrentThread());
            SynchronizationContext.SetSynchronizationContext(context);
            _ = new App();
        });
    }

    private static void HandleActivationRequest()
    {
        StartupConsoleReporter.Stage("single_instance_activation_received");
        ActivationRouter.RequestMainWindowActivation();
    }

    private static void AllowForegroundActivation(int processId)
    {
        if (!ShellNativeMethods.AllowSetForegroundWindow(processId))
        {
            StartupConsoleReporter.Stage("single_instance_foreground_handoff_unavailable");
        }
    }
}
