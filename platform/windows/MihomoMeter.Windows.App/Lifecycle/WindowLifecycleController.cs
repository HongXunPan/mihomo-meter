using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Presentation;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed class WindowLifecycleController : IDisposable
{
    private const int ShowWindowRestore = 9;

    private readonly Window _window;
    private readonly AppWindow _appWindow;
    private readonly nint _windowHandle;
    private readonly FloatingWidgetController _floatingWidget;
    private readonly NotificationAreaController _notificationArea;
    private readonly NotificationAreaRealtimeController _realtimeController;
    private readonly Action _showStatisticsWorkspace;
    private readonly Action _showQuotaWorkspace;
    private readonly Action _showConnectionAnalyticsWorkspace;
    private readonly Action _showControllerSettings;
    private readonly Action _showUpdates;
    private readonly Action<LiveConnectionRoute> _showLiveConnectionsWorkspace;
    private readonly Func<Task> _startStatistics;
    private readonly Func<Guid, Task> _stopStatistics;
    private readonly Func<Task> _refreshQuota;
    private readonly Func<Task> _prepareForExit;
    private bool _exitRequested;
    private bool _disposed;

    public WindowLifecycleController(
        Window window,
        Action<bool> floatingWidgetStateChanged,
        Func<NotificationAreaStatisticsMenuSnapshot> captureStatisticsSnapshot,
        Func<NotificationAreaQuotaMenuSnapshot> captureQuotaSnapshot,
        Func<NotificationAreaConnectionsMenuSnapshot> captureConnectionsSnapshot,
        NotificationAreaRealtimeController realtimeController,
        Action showStatisticsWorkspace,
        Action showQuotaWorkspace,
        Action showConnectionAnalyticsWorkspace,
        Action showControllerSettings,
        Action showUpdates,
        Action<LiveConnectionRoute> showLiveConnectionsWorkspace,
        Func<Task> startStatistics,
        Func<Guid, Task> stopStatistics,
        Func<Task> refreshQuota,
        Func<Task> prepareForExit)
    {
        _window = window ?? throw new ArgumentNullException(nameof(window));
        ArgumentNullException.ThrowIfNull(captureStatisticsSnapshot);
        ArgumentNullException.ThrowIfNull(captureQuotaSnapshot);
        ArgumentNullException.ThrowIfNull(captureConnectionsSnapshot);
        _realtimeController = realtimeController
            ?? throw new ArgumentNullException(nameof(realtimeController));
        _showStatisticsWorkspace = showStatisticsWorkspace
            ?? throw new ArgumentNullException(nameof(showStatisticsWorkspace));
        _showQuotaWorkspace = showQuotaWorkspace
            ?? throw new ArgumentNullException(nameof(showQuotaWorkspace));
        _showConnectionAnalyticsWorkspace = showConnectionAnalyticsWorkspace
            ?? throw new ArgumentNullException(nameof(showConnectionAnalyticsWorkspace));
        _showControllerSettings = showControllerSettings
            ?? throw new ArgumentNullException(nameof(showControllerSettings));
        _showUpdates = showUpdates ?? throw new ArgumentNullException(nameof(showUpdates));
        _showLiveConnectionsWorkspace = showLiveConnectionsWorkspace
            ?? throw new ArgumentNullException(nameof(showLiveConnectionsWorkspace));
        _startStatistics = startStatistics
            ?? throw new ArgumentNullException(nameof(startStatistics));
        _stopStatistics = stopStatistics
            ?? throw new ArgumentNullException(nameof(stopStatistics));
        _refreshQuota = refreshQuota ?? throw new ArgumentNullException(nameof(refreshQuota));
        _prepareForExit = prepareForExit ?? throw new ArgumentNullException(nameof(prepareForExit));
        _windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(window);
        var windowId = Win32Interop.GetWindowIdFromWindow(_windowHandle);
        _appWindow = AppWindow.GetFromWindowId(windowId)
            ?? throw new InvalidOperationException("无法取得 WinUI 主窗口对应的 AppWindow。");
        _appWindow.Closing += AppWindow_Closing;

        _floatingWidget = new FloatingWidgetController(
            QueueShowMainWindow,
            floatingWidgetStateChanged);
        try
        {
            _notificationArea = new NotificationAreaController(
                _windowHandle,
                QueueShowMainWindow,
                QueueShowStatisticsWorkspace,
                QueueShowQuotaWorkspace,
                QueueShowConnectionAnalyticsWorkspace,
                QueueShowControllerSettings,
                QueueShowUpdates,
                QueueToggleFloatingWidget,
                () => _floatingWidget.IsVisible,
                captureStatisticsSnapshot,
                captureQuotaSnapshot,
                captureConnectionsSnapshot,
                QueueShowLiveConnectionsWorkspace,
                QueueStartStatistics,
                QueueStopStatistics,
                QueueRefreshQuota,
                QueueExitApplication);
        }
        catch
        {
            _floatingWidget.Dispose();
            _appWindow.Closing -= AppWindow_Closing;
            throw;
        }

        _realtimeController.SnapshotChanged += ApplyRealtimeSnapshot;
        ApplyRealtimeSnapshot(_realtimeController.CaptureSnapshot());

        StartupConsoleReporter.Stage("window_lifecycle_ready");
    }

    private void ApplyRealtimeSnapshot(NotificationAreaRealtimeMenuSnapshot snapshot)
    {
        if (_disposed)
        {
            return;
        }

        try
        {
            _notificationArea.UpdateRealtimeSnapshot(snapshot);
            _floatingWidget.UpdateSnapshot(snapshot.Widget);
        }
        catch (Exception exception)
        {
            StartupConsoleReporter.Failure("notification_area_realtime_update", exception);
        }
    }

    public void ShowMainWindow()
    {
        if (_disposed)
        {
            return;
        }

        _appWindow.Show();
        ShellNativeMethods.ShowWindow(_windowHandle, ShowWindowRestore);
        ShellNativeMethods.SetForegroundWindow(_windowHandle);
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _appWindow.Closing -= AppWindow_Closing;
        _realtimeController.SnapshotChanged -= ApplyRealtimeSnapshot;
        _floatingWidget.Dispose();
        _notificationArea.Dispose();
    }

    private void AppWindow_Closing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        if (_disposed)
        {
            return;
        }

        args.Cancel = true;
        sender.Hide();
        StartupConsoleReporter.Stage("window_hidden_to_notification_area");
    }

    private void QueueShowMainWindow()
    {
        if (!_window.DispatcherQueue.TryEnqueue(() =>
            {
                StartupConsoleReporter.Stage("main_window_show_started");
                ShowMainWindow();
                StartupConsoleReporter.Stage("main_window_show_completed");
            }))
        {
            ReportDispatcherFailure("main_window_show_dispatch");
        }
    }

    private void QueueToggleFloatingWidget()
    {
        if (!_window.DispatcherQueue.TryEnqueue(() =>
            {
                try
                {
                    _floatingWidget.Toggle();
                }
                catch (Exception exception)
                {
                    StartupConsoleReporter.Failure("floating_widget_toggle", exception);
                }
            }))
        {
            ReportDispatcherFailure("floating_widget_toggle_dispatch");
        }
    }

    private void QueueShowStatisticsWorkspace()
    {
        if (!_window.DispatcherQueue.TryEnqueue(() =>
            {
                _showStatisticsWorkspace();
                ShowMainWindow();
            }))
        {
            ReportDispatcherFailure("statistics_workspace_show_dispatch");
        }
    }

    private void QueueShowQuotaWorkspace()
    {
        if (!_window.DispatcherQueue.TryEnqueue(() =>
            {
                _showQuotaWorkspace();
                ShowMainWindow();
            }))
        {
            ReportDispatcherFailure("quota_workspace_show_dispatch");
        }
    }

    private void QueueShowConnectionAnalyticsWorkspace()
    {
        if (!_window.DispatcherQueue.TryEnqueue(() =>
            {
                _showConnectionAnalyticsWorkspace();
                ShowMainWindow();
            }))
        {
            ReportDispatcherFailure("connection_analytics_workspace_show_dispatch");
        }
    }

    private void QueueShowControllerSettings()
    {
        if (!_window.DispatcherQueue.TryEnqueue(() => _showControllerSettings()))
        {
            ReportDispatcherFailure("controller_settings_show_dispatch");
        }
    }

    private void QueueShowUpdates()
    {
        if (!_window.DispatcherQueue.TryEnqueue(() => _showUpdates()))
        {
            ReportDispatcherFailure("updates_show_dispatch");
        }
    }

    private void QueueShowLiveConnectionsWorkspace(LiveConnectionRoute route)
    {
        if (!_window.DispatcherQueue.TryEnqueue(() =>
            {
                _showLiveConnectionsWorkspace(route);
                ShowMainWindow();
            }))
        {
            ReportDispatcherFailure("live_connections_workspace_show_dispatch");
        }
    }

    private void QueueStartStatistics()
    {
        QueueStatisticsOperation(
            _startStatistics,
            "notification_area_statistics_start");
    }

    private void QueueStopStatistics(Guid id)
    {
        QueueStatisticsOperation(
            () => _stopStatistics(id),
            "notification_area_statistics_stop");
    }

    private void QueueRefreshQuota()
    {
        QueueStatisticsOperation(
            _refreshQuota,
            "notification_area_quota_refresh");
    }

    private void QueueStatisticsOperation(Func<Task> operation, string source)
    {
        if (!_window.DispatcherQueue.TryEnqueue(() =>
            {
                _ = RunStatisticsOperationAsync(operation, source);
            }))
        {
            ReportDispatcherFailure($"{source}_dispatch");
        }
    }

    private static async Task RunStatisticsOperationAsync(
        Func<Task> operation,
        string source)
    {
        try
        {
            await operation();
        }
        catch (Exception exception)
        {
            StartupConsoleReporter.Failure(source, exception);
        }
    }

    private void QueueExitApplication()
    {
        if (!_window.DispatcherQueue.TryEnqueue(RequestExit))
        {
            ReportDispatcherFailure("application_exit_dispatch");
        }
    }

    private async void RequestExit()
    {
        if (_exitRequested)
        {
            return;
        }

        _exitRequested = true;
        StartupConsoleReporter.Stage("application_exit_requested");
        try
        {
            await _prepareForExit();
        }
        catch (Exception exception)
        {
            StartupConsoleReporter.Failure("application_exit_cleanup", exception);
        }
        finally
        {
            Dispose();
            _window.Close();
        }
    }

    private static void ReportDispatcherFailure(string source)
    {
        StartupConsoleReporter.Failure(
            source,
            new InvalidOperationException("无法把壳层操作发送到界面线程。"));
    }
}
