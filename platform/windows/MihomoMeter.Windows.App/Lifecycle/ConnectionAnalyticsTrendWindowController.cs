using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.App.Presentation;
using MihomoMeter.Windows.Core.Application;
using Windows.Graphics;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed class ConnectionAnalyticsTrendWindowController : IDisposable
{
    private readonly ConnectionAnalyticsTrendWindowViewModel _viewModel;
    private Window? _window;
    private ConnectionAnalyticsTrendView? _view;
    private bool _disposed;

    public ConnectionAnalyticsTrendWindowController(
        ConnectionAnalyticsCoordinator connectionAnalytics)
    {
        _viewModel = new ConnectionAnalyticsTrendWindowViewModel(connectionAnalytics);
    }

    public void Show(ConnectionAnalyticsTrendTarget target)
    {
        if (_disposed)
        {
            return;
        }

        EnsureWindow();
        _viewModel.Show(target);
        _window?.Activate();
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }
        _disposed = true;
        _viewModel.Reset();
        var window = _window;
        _window = null;
        _view?.Detach();
        _view = null;
        window?.Close();
    }

    private void EnsureWindow()
    {
        if (_window is not null)
        {
            return;
        }

        var view = new ConnectionAnalyticsTrendView(_viewModel);
        var window = new Window
        {
            Title = "Mihomo Meter · 连接分析趋势",
            Content = view,
        };
        window.Closed += Window_Closed;
        var windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(window);
        var windowId = Win32Interop.GetWindowIdFromWindow(windowHandle);
        var appWindow = AppWindow.GetFromWindowId(windowId)
            ?? throw new InvalidOperationException("无法取得 WinUI 连接趋势窗口对应的 AppWindow。");
        WindowsIconAssets.ApplyApplicationIcon(appWindow);
        appWindow.Resize(new SizeInt32(820, 610));
        _view = view;
        _window = window;
    }

    private void Window_Closed(object sender, WindowEventArgs args)
    {
        if (sender is Window window)
        {
            window.Closed -= Window_Closed;
        }
        _view?.Detach();
        _view = null;
        _window = null;
        _viewModel.Reset();
    }
}
