using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Infrastructure;
using MihomoMeter.Windows.App.Presentation;
using Windows.Graphics;

namespace MihomoMeter.Windows.App;

public sealed partial class MainWindow : Window
{
    private readonly WindowsAppServices _services;
    private bool _stopped;

    internal MainWindow(WindowsAppServices services)
    {
        _services = services;
        ViewModel = new MainWindowViewModel(
            DispatcherQueue,
            services.ConfigurationStore,
            services.Coordinator);
        StartupConsoleReporter.Stage("main_window_xaml_initialize_started");
        InitializeComponent();
        StartupConsoleReporter.Stage("main_window_xaml_initialize_completed");
        Title = "Mihomo Meter · Windows W1";
        ResizeForPreview();
    }

    public MainWindowViewModel ViewModel { get; }

    internal Task<bool> InitializeAsync()
    {
        return ViewModel.InitializeAsync();
    }

    internal async Task StopForApplicationTerminationAsync()
    {
        if (_stopped)
        {
            return;
        }

        _stopped = true;
        ViewModel.Detach();
        await _services.DisposeAsync();
    }

    public void SetFloatingWidgetEnabled(bool enabled)
    {
        FloatingWidgetStateText.Text = enabled ? "悬浮图标：开启" : "悬浮图标：关闭";
    }

    private async void ConnectButton_Click(object sender, RoutedEventArgs args)
    {
        var secret = SecretPasswordBox.Password;
        var forceEmptySecret = ForceEmptySecretCheckBox.IsChecked == true;
        SecretPasswordBox.Password = string.Empty;
        ForceEmptySecretCheckBox.IsChecked = false;
        try
        {
            await ViewModel.ConnectAsync(secret, forceEmptySecret);
        }
        catch (Exception exception)
        {
            ViewModel.ShowError(exception.Message);
        }
    }

    private async void DisconnectButton_Click(object sender, RoutedEventArgs args)
    {
        try
        {
            await ViewModel.DisconnectAsync();
        }
        catch (Exception exception)
        {
            ViewModel.ShowError(exception.Message);
        }
    }

    private void ResizeForPreview()
    {
        var windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(this);
        var windowId = Win32Interop.GetWindowIdFromWindow(windowHandle);
        AppWindow.GetFromWindowId(windowId)?.Resize(new SizeInt32(860, 720));
    }
}
