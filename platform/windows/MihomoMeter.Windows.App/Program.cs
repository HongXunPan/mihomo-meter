using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.Windows.AppLifecycle;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Lifecycle;

namespace MihomoMeter.Windows.App;

internal static class Program
{
    private const string MainInstanceKey = "MihomoMeter.Windows.App.Main";

    [STAThread]
    public static async Task Main()
    {
        W0ConsoleReporter.Initialize();
        try
        {
            await RunAsync();
        }
        catch (Exception exception)
        {
            W0ConsoleReporter.Failure("program_main", exception);
            throw;
        }
    }

    private static async Task RunAsync()
    {
        W0ConsoleReporter.Stage("single_instance_registration_started");
        WinRT.ComWrappersSupport.InitializeComWrappers();
        var activationArguments = AppInstance.GetCurrent().GetActivatedEventArgs();
        var mainInstance = AppInstance.FindOrRegisterForKey(MainInstanceKey);
        if (!mainInstance.IsCurrent)
        {
            W0ConsoleReporter.Stage("single_instance_redirect_started");
            if (!ShellNativeMethods.AllowSetForegroundWindow(mainInstance.ProcessId))
            {
                W0ConsoleReporter.Stage("single_instance_foreground_handoff_unavailable");
            }

            await mainInstance.RedirectActivationToAsync(activationArguments);
            W0ConsoleReporter.Stage("single_instance_redirect_completed");
            return;
        }

        mainInstance.Activated += MainInstance_Activated;
        try
        {
            W0ConsoleReporter.Stage("single_instance_primary_ready");
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
            mainInstance.Activated -= MainInstance_Activated;
        }
    }

    private static void MainInstance_Activated(object? sender, AppActivationArguments args)
    {
        W0ConsoleReporter.Stage("single_instance_activation_received");
        ActivationRouter.RequestMainWindowActivation();
    }
}
