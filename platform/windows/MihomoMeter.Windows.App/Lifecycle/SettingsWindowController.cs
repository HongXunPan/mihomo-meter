using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.App.Presentation;
using Windows.Graphics;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed class SettingsWindowController : IDisposable
{
    private readonly MainWindowViewModel _mainWindowViewModel;
    private readonly WindowsUpdateWorkspaceViewModel _updateViewModel;
    private Window? _window;
    private SettingsWorkspaceView? _view;
    private bool _disposed;

    public SettingsWindowController(
        MainWindowViewModel mainWindowViewModel,
        WindowsUpdateWorkspaceViewModel updateViewModel)
    {
        _mainWindowViewModel = mainWindowViewModel;
        _updateViewModel = updateViewModel;
    }

    public void ShowConnectionSettings()
    {
        EnsureWindow();
        _view?.ShowConnectionSettings();
        _window?.Activate();
    }

    public void ShowUpdates()
    {
        EnsureWindow();
        _view?.ShowUpdates();
        _window?.Activate();
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
        var windowId = Win32Interop.GetWindowIdFromWindow(windowHandle);
        AppWindow.GetFromWindowId(windowId)?.Resize(new SizeInt32(780, 620));
        _view = view;
        _window = window;
    }

    private void Window_Closed(object sender, WindowEventArgs args)
    {
        if (sender is Window window)
        {
            window.Closed -= Window_Closed;
        }

        _view = null;
        _window = null;
    }
}
