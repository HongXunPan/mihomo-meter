using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Interop;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed class WindowLifecycleController : IDisposable
{
    private const int ShowWindowRestore = 9;

    private readonly Window _window;
    private readonly AppWindow _appWindow;
    private readonly nint _windowHandle;
    private readonly FloatingWidgetController _floatingWidget;
    private readonly NotificationAreaController _notificationArea;
    private bool _exitRequested;
    private bool _disposed;

    public WindowLifecycleController(Window window, Action<bool> floatingWidgetStateChanged)
    {
        _window = window ?? throw new ArgumentNullException(nameof(window));
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
                QueueToggleFloatingWidget,
                () => _floatingWidget.IsVisible,
                QueueExitApplication);
        }
        catch
        {
            _floatingWidget.Dispose();
            _appWindow.Closing -= AppWindow_Closing;
            throw;
        }

        W0ConsoleReporter.Stage("window_lifecycle_ready");
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
        _floatingWidget.Dispose();
        _notificationArea.Dispose();
    }

    private void AppWindow_Closing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        if (_exitRequested)
        {
            return;
        }

        args.Cancel = true;
        sender.Hide();
        W0ConsoleReporter.Stage("window_hidden_to_notification_area");
    }

    private void QueueShowMainWindow()
    {
        if (!_window.DispatcherQueue.TryEnqueue(() =>
            {
                W0ConsoleReporter.Stage("main_window_show_started");
                ShowMainWindow();
                W0ConsoleReporter.Stage("main_window_show_completed");
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
                    W0ConsoleReporter.Failure("floating_widget_toggle", exception);
                }
            }))
        {
            ReportDispatcherFailure("floating_widget_toggle_dispatch");
        }
    }

    private void QueueExitApplication()
    {
        if (!_window.DispatcherQueue.TryEnqueue(RequestExit))
        {
            ReportDispatcherFailure("application_exit_dispatch");
        }
    }

    private void RequestExit()
    {
        if (_exitRequested)
        {
            return;
        }

        _exitRequested = true;
        W0ConsoleReporter.Stage("application_exit_requested");
        Dispose();
        _window.Close();
    }

    private static void ReportDispatcherFailure(string source)
    {
        W0ConsoleReporter.Failure(
            source,
            new InvalidOperationException("无法把壳层操作发送到界面线程。"));
    }
}
