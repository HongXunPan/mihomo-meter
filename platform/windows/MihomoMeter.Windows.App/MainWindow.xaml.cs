using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Infrastructure;
using MihomoMeter.Windows.App.Lifecycle;
using MihomoMeter.Windows.App.Presentation;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using Windows.Graphics;

namespace MihomoMeter.Windows.App;

public sealed partial class MainWindow : Window
{
    private readonly WindowsAppServices _services;
    private readonly RealtimeMonitoringView _realtimeView;
    private readonly TrafficStatisticsWorkspaceView _statisticsView;
    private readonly LiveConnectionWorkspaceView _liveConnectionView;
    private readonly ConnectionAnalyticsWorkspaceView _connectionAnalyticsView;
    private readonly ConnectionAnalyticsTrendWindowController _connectionTrendWindow;
    private readonly ProxyTrafficWorkspaceView _proxyTrafficView;
    private readonly SubscriptionQuotaWorkspaceView _quotaView;
    private readonly WindowsUpdateWorkspaceView _updateView;
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
        LiveConnectionViewModel = new LiveConnectionWorkspaceViewModel(
            DispatcherQueue,
            services.Coordinator);
        ConnectionAnalyticsViewModel = new ConnectionAnalyticsWorkspaceViewModel(
            DispatcherQueue,
            services.ConnectionAnalytics);
        var assemblyVersion = typeof(App).Assembly.GetName().Version
            ?? throw new InvalidOperationException("无法读取 Windows 应用版本。");
        UpdateViewModel = new WindowsUpdateWorkspaceViewModel(
            services.UpdateChecker,
            ReleaseVersion.FromAssemblyVersion(assemblyVersion));
        NotificationAreaStatistics = new NotificationAreaStatisticsController(
            DispatcherQueue,
            services.Coordinator,
            services.Statistics);
        NotificationAreaQuota = new NotificationAreaQuotaController(
            DispatcherQueue,
            services.Quota);
        NotificationAreaConnections = new NotificationAreaConnectionController(
            DispatcherQueue,
            services.Coordinator);
        StartupConsoleReporter.Stage("main_window_xaml_initialize_started");
        InitializeComponent();
        if (WorkspaceNavigation.SettingsItem is NavigationViewItem settingsItem)
        {
            settingsItem.Content = "关于与更新";
        }
        StartupConsoleReporter.Stage("main_window_xaml_initialize_completed");
        _realtimeView = new RealtimeMonitoringView(ViewModel);
        _statisticsView = new TrafficStatisticsWorkspaceView(StatisticsViewModel);
        _liveConnectionView = new LiveConnectionWorkspaceView(LiveConnectionViewModel);
        _connectionTrendWindow = new ConnectionAnalyticsTrendWindowController(
            services.ConnectionAnalytics);
        _connectionAnalyticsView = new ConnectionAnalyticsWorkspaceView(
            ConnectionAnalyticsViewModel,
            _connectionTrendWindow.Show);
        _proxyTrafficView = new ProxyTrafficWorkspaceView(
            _statisticsView,
            _liveConnectionView,
            _connectionAnalyticsView);
        _quotaView = new SubscriptionQuotaWorkspaceView(QuotaViewModel, this);
        _updateView = new WindowsUpdateWorkspaceView(UpdateViewModel);
        WorkspaceNavigation.SelectionChanged += WorkspaceNavigation_SelectionChanged;
        WorkspaceNavigation.SelectedItem = RealtimeNavigationItem;
        ShowWorkspace("realtime");
        Title = "Mihomo Meter · Windows W3-2";
        ResizeForPreview();
    }

    public MainWindowViewModel ViewModel { get; }

    public TrafficStatisticsWorkspaceViewModel StatisticsViewModel { get; }

    public SubscriptionQuotaWorkspaceViewModel QuotaViewModel { get; }

    public LiveConnectionWorkspaceViewModel LiveConnectionViewModel { get; }

    public ConnectionAnalyticsWorkspaceViewModel ConnectionAnalyticsViewModel { get; }

    public WindowsUpdateWorkspaceViewModel UpdateViewModel { get; }

    internal NotificationAreaStatisticsController NotificationAreaStatistics { get; }

    internal NotificationAreaQuotaController NotificationAreaQuota { get; }

    internal NotificationAreaConnectionController NotificationAreaConnections { get; }

    internal async Task<bool> InitializeAsync()
    {
        await StatisticsViewModel.InitializeAsync();
        await ConnectionAnalyticsViewModel.InitializeAsync();
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
        LiveConnectionViewModel.Detach();
        ConnectionAnalyticsViewModel.Detach();
        _connectionTrendWindow.Dispose();
        NotificationAreaStatistics.Dispose();
        NotificationAreaQuota.Dispose();
        NotificationAreaConnections.Dispose();
        await _services.DisposeAsync();
    }

    public void SetFloatingWidgetEnabled(bool enabled)
    {
        FloatingWidgetStateText.Text = enabled ? "悬浮图标：开启" : "悬浮图标：关闭";
    }

    internal void ShowStatisticsWorkspace()
    {
        WorkspaceNavigation.SelectedItem = StatisticsNavigationItem;
        _proxyTrafficView.ShowStatistics();
        ShowWorkspace("statistics");
    }

    internal void ShowLiveConnectionsWorkspace(LiveConnectionRoute route)
    {
        WorkspaceNavigation.SelectedItem = StatisticsNavigationItem;
        _proxyTrafficView.ShowLiveConnections(route);
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
        if (args.IsSettingsSelected)
        {
            ShowWorkspace("updates");
            return;
        }

        ShowWorkspace(args.SelectedItemContainer?.Tag?.ToString());
    }

    private void ShowWorkspace(string? section)
    {
        WorkspaceContent.Content = section switch
        {
            "statistics" => _proxyTrafficView,
            "quota" => _quotaView,
            "updates" => _updateView,
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
