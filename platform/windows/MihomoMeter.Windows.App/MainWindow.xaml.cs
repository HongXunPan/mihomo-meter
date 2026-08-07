using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Infrastructure;
using MihomoMeter.Windows.App.Presentation;
using Windows.Graphics;

namespace MihomoMeter.Windows.App;

public sealed partial class MainWindow : Window
{
    private readonly WindowsAppServices _services;
    private readonly RealtimeMonitoringView _realtimeView;
    private readonly TrafficStatisticsWorkspaceView _statisticsView;
    private bool _stopped;

    internal MainWindow(WindowsAppServices services)
    {
        _services = services;
        ViewModel = new MainWindowViewModel(
            DispatcherQueue,
            services.ConfigurationStore,
            services.Coordinator);
        StatisticsViewModel = new TrafficStatisticsWorkspaceViewModel(
            DispatcherQueue,
            services.Coordinator,
            services.Statistics);
        StartupConsoleReporter.Stage("main_window_xaml_initialize_started");
        InitializeComponent();
        StartupConsoleReporter.Stage("main_window_xaml_initialize_completed");
        _realtimeView = new RealtimeMonitoringView(ViewModel);
        _statisticsView = new TrafficStatisticsWorkspaceView(StatisticsViewModel);
        WorkspaceNavigation.SelectionChanged += WorkspaceNavigation_SelectionChanged;
        WorkspaceNavigation.SelectedItem = RealtimeNavigationItem;
        ShowWorkspace("realtime");
        Title = "Mihomo Meter · Windows W2B";
        ResizeForPreview();
    }

    public MainWindowViewModel ViewModel { get; }

    public TrafficStatisticsWorkspaceViewModel StatisticsViewModel { get; }

    internal async Task<bool> InitializeAsync()
    {
        await StatisticsViewModel.InitializeAsync();
        return await ViewModel.InitializeAsync();
    }

    internal async Task StopForApplicationTerminationAsync()
    {
        if (_stopped)
        {
            return;
        }

        _stopped = true;
        ViewModel.Detach();
        StatisticsViewModel.Detach();
        await _services.DisposeAsync();
    }

    public void SetFloatingWidgetEnabled(bool enabled)
    {
        FloatingWidgetStateText.Text = enabled ? "悬浮图标：开启" : "悬浮图标：关闭";
    }

    private void WorkspaceNavigation_SelectionChanged(
        NavigationView sender,
        NavigationViewSelectionChangedEventArgs args)
    {
        ShowWorkspace(args.SelectedItemContainer?.Tag?.ToString());
    }

    private void ShowWorkspace(string? section)
    {
        WorkspaceContent.Content = section == "statistics"
            ? _statisticsView
            : _realtimeView;
    }

    private void ResizeForPreview()
    {
        var windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(this);
        var windowId = Win32Interop.GetWindowIdFromWindow(windowHandle);
        AppWindow.GetFromWindowId(windowId)?.Resize(new SizeInt32(980, 720));
    }
}
