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
    private readonly SubscriptionQuotaWorkspaceView _quotaView;
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
        QuotaViewModel = new SubscriptionQuotaWorkspaceViewModel(
            DispatcherQueue,
            services.Quota);
        NotificationAreaStatistics = new NotificationAreaStatisticsController(
            DispatcherQueue,
            services.Coordinator,
            services.Statistics);
        NotificationAreaQuota = new NotificationAreaQuotaController(
            DispatcherQueue,
            services.Quota);
        StartupConsoleReporter.Stage("main_window_xaml_initialize_started");
        InitializeComponent();
        StartupConsoleReporter.Stage("main_window_xaml_initialize_completed");
        _realtimeView = new RealtimeMonitoringView(ViewModel);
        _statisticsView = new TrafficStatisticsWorkspaceView(StatisticsViewModel);
        _quotaView = new SubscriptionQuotaWorkspaceView(QuotaViewModel, this);
        WorkspaceNavigation.SelectionChanged += WorkspaceNavigation_SelectionChanged;
        WorkspaceNavigation.SelectedItem = RealtimeNavigationItem;
        ShowWorkspace("realtime");
        Title = "Mihomo Meter · Windows W2C";
        ResizeForPreview();
    }

    public MainWindowViewModel ViewModel { get; }

    public TrafficStatisticsWorkspaceViewModel StatisticsViewModel { get; }

    public SubscriptionQuotaWorkspaceViewModel QuotaViewModel { get; }

    internal NotificationAreaStatisticsController NotificationAreaStatistics { get; }

    internal NotificationAreaQuotaController NotificationAreaQuota { get; }

    internal async Task<bool> InitializeAsync()
    {
        await StatisticsViewModel.InitializeAsync();
        await QuotaViewModel.InitializeAsync();
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
        QuotaViewModel.Detach();
        NotificationAreaStatistics.Dispose();
        NotificationAreaQuota.Dispose();
        await _services.DisposeAsync();
    }

    public void SetFloatingWidgetEnabled(bool enabled)
    {
        FloatingWidgetStateText.Text = enabled ? "悬浮图标：开启" : "悬浮图标：关闭";
    }

    internal void ShowStatisticsWorkspace()
    {
        WorkspaceNavigation.SelectedItem = StatisticsNavigationItem;
        ShowWorkspace("statistics");
    }

    internal void ShowQuotaWorkspace()
    {
        WorkspaceNavigation.SelectedItem = QuotaNavigationItem;
        ShowWorkspace("quota");
    }

    private void WorkspaceNavigation_SelectionChanged(
        NavigationView sender,
        NavigationViewSelectionChangedEventArgs args)
    {
        ShowWorkspace(args.SelectedItemContainer?.Tag?.ToString());
    }

    private void ShowWorkspace(string? section)
    {
        WorkspaceContent.Content = section switch
        {
            "statistics" => _statisticsView,
            "quota" => _quotaView,
            _ => _realtimeView,
        };
    }

    private void ResizeForPreview()
    {
        var windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(this);
        var windowId = Win32Interop.GetWindowIdFromWindow(windowHandle);
        AppWindow.GetFromWindowId(windowId)?.Resize(new SizeInt32(980, 720));
    }
}
