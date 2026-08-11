using Microsoft.UI.Xaml;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Infrastructure;
using MihomoMeter.Windows.App.Lifecycle;

namespace MihomoMeter.Windows.App;

public partial class App : Application
{
    private MainWindow? _window;
    private WindowLifecycleController? _windowLifecycle;

    public App()
    {
        UnhandledException += App_UnhandledException;
        StartupConsoleReporter.Stage("app_xaml_initialize_started");
        try
        {
            InitializeComponent();
            StartupConsoleReporter.Stage("app_xaml_initialize_completed");
        }
        catch (Exception exception)
        {
            StartupConsoleReporter.Failure("app_constructor", exception);
            throw;
        }
    }

    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        StartupConsoleReporter.Stage("app_launch_entered");
        WindowsAppServices? services = null;
        try
        {
            services = WindowsAppServices.Create();
            var window = new MainWindow(services);
            _window = window;
            _windowLifecycle = new WindowLifecycleController(
                window,
                window.SetFloatingWidgetEnabled,
                window.NotificationAreaStatistics.CaptureSnapshot,
                window.NotificationAreaQuota.CaptureSnapshot,
                window.NotificationAreaConnections.CaptureSnapshot,
                window.NotificationAreaRealtime,
                window.ShowStatisticsWorkspace,
                window.ShowQuotaWorkspace,
                window.ShowConnectionAnalyticsWorkspace,
                window.ShowControllerSettings,
                window.ShowUpdates,
                window.ShowLiveConnectionsWorkspace,
                window.NotificationAreaStatistics.StartSuggestedIntervalAsync,
                window.NotificationAreaStatistics.StopIntervalAsync,
                window.NotificationAreaQuota.RefreshAllAsync,
                window.StopForApplicationTerminationAsync);
            ActivationRouter.Register(HandleRedirectedActivation);
            var hasStoredConfiguration = await window.InitializeAsync();
            if (!hasStoredConfiguration)
            {
                window.ShowFirstConnectionGuide();
                _windowLifecycle.ShowMainWindow();
            }

            StartupConsoleReporter.Stage("app_launch_completed");
        }
        catch (Exception exception)
        {
            try
            {
                _windowLifecycle?.Dispose();
                if (_window is not null)
                {
                    await _window.StopForApplicationTerminationAsync();
                }
                else if (services is not null)
                {
                    await services.DisposeAsync();
                }
            }
            catch (Exception cleanupException)
            {
                StartupConsoleReporter.Failure("app_launch_cleanup", cleanupException);
            }

            StartupConsoleReporter.Failure("app_launch", exception);
            throw;
        }
    }

    private void HandleRedirectedActivation()
    {
        var dispatcher = _window?.DispatcherQueue;
        if (dispatcher is null || !dispatcher.TryEnqueue(() =>
            {
                StartupConsoleReporter.Stage("redirected_activation_window_show_started");
                _windowLifecycle?.ShowMainWindow();
                StartupConsoleReporter.Stage("redirected_activation_window_show_completed");
            }))
        {
            StartupConsoleReporter.Failure(
                "redirected_activation_dispatch",
                new InvalidOperationException("无法把单实例唤起请求发送到界面线程。"));
        }
    }

    private static void App_UnhandledException(
        object sender,
        Microsoft.UI.Xaml.UnhandledExceptionEventArgs args)
    {
        StartupConsoleReporter.Failure("xaml_unhandled_exception", args.Exception);
    }
}
