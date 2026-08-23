using Microsoft.UI.Xaml;
using Microsoft.Windows.AppLifecycle;
using Microsoft.Windows.AppNotifications;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Infrastructure;
using MihomoMeter.Windows.App.Infrastructure.Notifications;
using MihomoMeter.Windows.App.Lifecycle;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App;

public partial class App : Application
{
    private readonly bool _isStartupLaunch;
    private readonly AppActivationArguments? _initialActivationArguments;
    private readonly Action _registerCrashRecoveryRestart;
    private readonly Action _unregisterCrashRecoveryRestart;
    private MainWindow? _window;
    private WindowLifecycleController? _windowLifecycle;

    public App()
        : this(
            isStartupLaunch: false,
            initialActivationArguments: null,
            registerCrashRecoveryRestart: static () => { },
            unregisterCrashRecoveryRestart: static () => { })
    {
    }

    internal App(
        bool isStartupLaunch,
        AppActivationArguments? initialActivationArguments,
        Action registerCrashRecoveryRestart,
        Action unregisterCrashRecoveryRestart)
    {
        _isStartupLaunch = isStartupLaunch;
        _initialActivationArguments = initialActivationArguments;
        _registerCrashRecoveryRestart = registerCrashRecoveryRestart
            ?? throw new ArgumentNullException(nameof(registerCrashRecoveryRestart));
        _unregisterCrashRecoveryRestart = unregisterCrashRecoveryRestart
            ?? throw new ArgumentNullException(nameof(unregisterCrashRecoveryRestart));
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
        WindowsSystemNotificationService? notificationService = null;
        try
        {
            notificationService = new WindowsSystemNotificationService();
            notificationService.Activated += ActivationRouter.RequestActivation;
            notificationService.Register();
            var notificationActivationHandled = false;
            if (_initialActivationArguments?.Kind == ExtendedActivationKind.AppNotification
                && _initialActivationArguments.Data
                    is AppNotificationActivatedEventArgs notificationArgs)
            {
                notificationActivationHandled = notificationService.TryHandleActivation(
                    notificationArgs);
            }
            var protocolActivationHandled = StartupActivation.TryResolveProtocolTarget(
                _initialActivationArguments,
                out var protocolTarget);
            if (protocolActivationHandled)
            {
                ActivationRouter.RequestActivation(protocolTarget);
            }

            services = WindowsAppServices.Create(notificationService);
            notificationService = null;
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
                async () =>
                {
                    _unregisterCrashRecoveryRestart();
                    await window.StopForApplicationTerminationAsync();
                });
            var hasStoredConfiguration = await window.InitializeAsync();
            var shouldShowFirstConnectionGuide =
                !hasStoredConfiguration && !_isStartupLaunch;
            if (shouldShowFirstConnectionGuide
                && !notificationActivationHandled
                && !protocolActivationHandled)
            {
                window.ShowFirstConnectionGuide();
                _windowLifecycle.ShowMainWindow();
            }
            ActivationRouter.Register(HandleRedirectedActivation);
            _registerCrashRecoveryRestart();

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
                notificationService?.Dispose();
            }
            catch (Exception cleanupException)
            {
                StartupConsoleReporter.Failure("app_launch_cleanup", cleanupException);
            }

            StartupConsoleReporter.Failure("app_launch", exception);
            throw;
        }
    }

    private void HandleRedirectedActivation(AppActivationTarget target)
    {
        var dispatcher = _window?.DispatcherQueue;
        if (dispatcher is null || !dispatcher.TryEnqueue(() =>
            {
                StartupConsoleReporter.Stage("redirected_activation_window_show_started");
                switch (target)
                {
                    case AppActivationTarget.Statistics:
                        _window?.ShowStatisticsWorkspace();
                        _windowLifecycle?.ShowMainWindow();
                        break;
                    case AppActivationTarget.SubscriptionQuota:
                        _window?.ShowQuotaWorkspace();
                        _windowLifecycle?.ShowMainWindow();
                        break;
                    case AppActivationTarget.ControllerSettings:
                        _window?.ShowControllerSettings();
                        break;
                    default:
                        _windowLifecycle?.ShowMainWindow();
                        break;
                }
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
