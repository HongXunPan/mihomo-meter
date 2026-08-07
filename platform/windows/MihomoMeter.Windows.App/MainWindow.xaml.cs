using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.App.Diagnostics;
using Windows.Graphics;

namespace MihomoMeter.Windows.App;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        W0ConsoleReporter.Stage("main_window_xaml_initialize_started");
        InitializeComponent();
        W0ConsoleReporter.Stage("main_window_xaml_initialize_completed");
        Title = "Mihomo Meter · Windows W0";
        ResizeForGate();
    }

    public void SetFloatingWidgetEnabled(bool enabled)
    {
        FloatingWidgetStateText.Text = enabled
            ? "已开启；拖动只在当前进程内保留位置，单击可打开主窗口。"
            : "未开启；可从通知区域菜单开启。";
    }

    private void ResizeForGate()
    {
        var windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(this);
        var windowId = Win32Interop.GetWindowIdFromWindow(windowHandle);
        AppWindow.GetFromWindowId(windowId)?.Resize(new SizeInt32(780, 500));
    }
}
