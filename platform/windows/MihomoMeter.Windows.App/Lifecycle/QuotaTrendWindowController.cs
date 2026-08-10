using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.App.Presentation;
using Windows.Graphics;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed class QuotaTrendWindowController : IDisposable
{
    private Window? _window;
    private SubscriptionQuotaCardViewModel? _target;
    private bool _disposed;

    public void Show(SubscriptionQuotaCardViewModel target)
    {
        if (_disposed)
        {
            return;
        }

        if (_window is null || !ReferenceEquals(_target, target))
        {
            ReplaceWindow(target);
        }
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
        _target = null;
        window?.Close();
    }

    private void ReplaceWindow(SubscriptionQuotaCardViewModel target)
    {
        var previous = _window;
        _window = null;
        _target = target;
        previous?.Close();

        var window = new Window
        {
            Title = $"Mihomo Meter · {target.Name} · 配额趋势",
            Content = new QuotaTrendDetailView(target),
        };
        window.Closed += Window_Closed;
        var windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(window);
        var windowId = Win32Interop.GetWindowIdFromWindow(windowHandle);
        AppWindow.GetFromWindowId(windowId)?.Resize(new SizeInt32(860, 620));
        _window = window;
    }

    private void Window_Closed(object sender, WindowEventArgs args)
    {
        if (sender is Window window)
        {
            window.Closed -= Window_Closed;
        }
        if (ReferenceEquals(_window, sender))
        {
            _window = null;
            _target = null;
        }
    }
}
