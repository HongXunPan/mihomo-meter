using Microsoft.UI.Xaml;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Lifecycle;

namespace MihomoMeter.Windows.App;

public partial class App : Application
{
    private MainWindow? _window;
    private WindowLifecycleController? _windowLifecycle;

    public App()
    {
        UnhandledException += App_UnhandledException;
        W0ConsoleReporter.Stage("app_xaml_initialize_started");
        try
        {
            InitializeComponent();
            W0ConsoleReporter.Stage("app_xaml_initialize_completed");
        }
        catch (Exception exception)
        {
            W0ConsoleReporter.Failure("app_constructor", exception);
            throw;
        }
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        W0ConsoleReporter.Stage("app_launch_entered");
        try
        {
            var window = new MainWindow();
            _window = window;
            _windowLifecycle = new WindowLifecycleController(
                window,
                window.SetFloatingWidgetEnabled);
            ActivationRouter.Register(HandleRedirectedActivation);
            _windowLifecycle.ShowMainWindow();
            W0ConsoleReporter.Stage("app_launch_completed");
        }
        catch (Exception exception)
        {
            W0ConsoleReporter.Failure("app_launch", exception);
            throw;
        }
    }

    private void HandleRedirectedActivation()
    {
        var dispatcher = _window?.DispatcherQueue;
        if (dispatcher is null || !dispatcher.TryEnqueue(() =>
            {
                W0ConsoleReporter.Stage("redirected_activation_window_show_started");
                _windowLifecycle?.ShowMainWindow();
                W0ConsoleReporter.Stage("redirected_activation_window_show_completed");
            }))
        {
            W0ConsoleReporter.Failure(
                "redirected_activation_dispatch",
                new InvalidOperationException("无法把单实例唤起请求发送到界面线程。"));
        }
    }

    private static void App_UnhandledException(
        object sender,
        Microsoft.UI.Xaml.UnhandledExceptionEventArgs args)
    {
        W0ConsoleReporter.Failure("xaml_unhandled_exception", args.Exception);
    }
}
