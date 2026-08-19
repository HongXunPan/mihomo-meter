using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Presentation;
using Windows.Graphics;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed class SettingsWindowController : IDisposable
{
    private readonly nint _ownerWindowHandle;
    private readonly MainWindowViewModel _mainWindowViewModel;
    private readonly WindowsUpdateWorkspaceViewModel _updateViewModel;
    private Window? _window;
    private SettingsWorkspaceView? _view;
    private nint _windowHandle;
    private bool _disposed;

    public SettingsWindowController(
        Window ownerWindow,
        MainWindowViewModel mainWindowViewModel,
        WindowsUpdateWorkspaceViewModel updateViewModel)
    {
        ArgumentNullException.ThrowIfNull(ownerWindow);
        _ownerWindowHandle = WinRT.Interop.WindowNative.GetWindowHandle(ownerWindow);
        _mainWindowViewModel = mainWindowViewModel;
        _updateViewModel = updateViewModel;
    }

    public void ShowConnectionSettings()
    {
        EnsureWindow();
        _view?.ShowConnectionSettings();
        ActivateWindow();
    }

    public void ShowUpdates()
    {
        EnsureWindow();
        _view?.ShowUpdates();
        ActivateWindow();
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        var window = _window;
        _window = null;
        _view = null;
        _windowHandle = nint.Zero;
        window?.Close();
    }

    private void EnsureWindow()
    {
        if (_disposed || _window is not null)
        {
            return;
        }

        var view = new SettingsWorkspaceView(_mainWindowViewModel, _updateViewModel);
        var window = new Window
        {
            Title = "Mihomo Meter · 设置",
            Content = view,
        };
        window.Closed += Window_Closed;
        var windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(window);
        WindowOwnershipNativeMethods.SetOwner(windowHandle, _ownerWindowHandle);
        var windowId = Win32Interop.GetWindowIdFromWindow(windowHandle);
        var appWindow = AppWindow.GetFromWindowId(windowId)
            ?? throw new InvalidOperationException("无法取得 WinUI 设置窗口对应的 AppWindow。");
        WindowsIconAssets.ApplyApplicationIcon(appWindow);
        appWindow.Resize(new SizeInt32(780, 620));
        _view = view;
        _window = window;
        _windowHandle = windowHandle;
    }

    private void ActivateWindow()
    {
        var window = _window;
        if (window is null)
        {
            return;
        }

        window.Activate();
        if (_windowHandle != nint.Zero)
        {
            ShellNativeMethods.SetForegroundWindow(_windowHandle);
        }
    }

    private void Window_Closed(object sender, WindowEventArgs args)
    {
        if (sender is Window window)
        {
            window.Closed -= Window_Closed;
        }

        _view = null;
        _window = null;
        _windowHandle = nint.Zero;
    }
}
