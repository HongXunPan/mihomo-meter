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
    private readonly TrafficStatisticsWorkspaceView _statisticsView;
    private readonly LiveConnectionWorkspaceView _liveConnectionView;
    private readonly ConnectionAnalyticsWorkspaceView _connectionAnalyticsView;
    private readonly ConnectionAnalyticsTrendWindowController _connectionTrendWindow;
    private readonly QuotaTrendWindowController _quotaTrendWindow;
    private readonly ProxyTrafficWorkspaceView _proxyTrafficView;
    private readonly SubscriptionQuotaWorkspaceView _quotaView;
    private readonly SettingsWindowController _settingsWindow;
    private readonly FirstConnectionGuideView _firstConnectionGuideView;
    private NavigationViewItem? _selectedWorkspaceItem;
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
        var startupViewModel = new StartupSettingsViewModel(
            services.StartupRegistration);
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
        NotificationAreaRealtime = new NotificationAreaRealtimeController(
            DispatcherQueue,
            services.Coordinator);
        StartupConsoleReporter.Stage("main_window_xaml_initialize_started");
        InitializeComponent();
        if (WorkspaceNavigation.SettingsItem is NavigationViewItem settingsItem)
        {
            settingsItem.Content = "设置";
        }
        StartupConsoleReporter.Stage("main_window_xaml_initialize_completed");
        _statisticsView = new TrafficStatisticsWorkspaceView(StatisticsViewModel);
        _liveConnectionView = new LiveConnectionWorkspaceView(LiveConnectionViewModel);
        _connectionTrendWindow = new ConnectionAnalyticsTrendWindowController(
            services.ConnectionAnalytics);
        _connectionAnalyticsView = new ConnectionAnalyticsWorkspaceView(
            ConnectionAnalyticsViewModel,
            _connectionTrendWindow.Show);
        _proxyTrafficView = new ProxyTrafficWorkspaceView(
            _statisticsView,
            _liveConnectionView);
        _quotaTrendWindow = new QuotaTrendWindowController();
        _quotaView = new SubscriptionQuotaWorkspaceView(
            QuotaViewModel,
            this,
            _quotaTrendWindow.Show);
        _settingsWindow = new SettingsWindowController(
            this,
            ViewModel,
            UpdateViewModel,
            startupViewModel);
        _firstConnectionGuideView = new FirstConnectionGuideView(
            _settingsWindow.ShowConnectionSettings);
        ViewModel.ConfigurationValidated += ViewModel_ConfigurationValidated;
        WorkspaceNavigation.SelectionChanged += WorkspaceNavigation_SelectionChanged;
        WorkspaceNavigation.SelectedItem = StatisticsNavigationItem;
        _selectedWorkspaceItem = StatisticsNavigationItem;
        ShowWorkspace("statistics");
        Title = "Mihomo Meter";
        ResizeWindow();
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

    internal NotificationAreaRealtimeController NotificationAreaRealtime { get; }

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
        ViewModel.ConfigurationValidated -= ViewModel_ConfigurationValidated;
        _connectionTrendWindow.Dispose();
        _quotaTrendWindow.Dispose();
        _settingsWindow.Dispose();
        NotificationAreaStatistics.Dispose();
        NotificationAreaQuota.Dispose();
        NotificationAreaConnections.Dispose();
        NotificationAreaRealtime.Dispose();
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

    internal void ShowConnectionAnalyticsWorkspace()
    {
        WorkspaceNavigation.SelectedItem = ConnectionAnalyticsNavigationItem;
        ShowWorkspace("connectionAnalytics");
    }

    internal void ShowControllerSettings()
    {
        _settingsWindow.ShowConnectionSettings();
    }

    internal void ShowUpdates()
    {
        _settingsWindow.ShowUpdates();
    }

    internal void ShowFirstConnectionGuide()
    {
        WorkspaceContent.Content = _firstConnectionGuideView;
    }

    private void WorkspaceNavigation_SelectionChanged(
        NavigationView sender,
        NavigationViewSelectionChangedEventArgs args)
    {
        if (args.IsSettingsSelected)
        {
            if (_selectedWorkspaceItem is not null)
            {
                WorkspaceNavigation.SelectedItem = _selectedWorkspaceItem;
            }
            _settingsWindow.ShowConnectionSettings();
            return;
        }

        if (args.SelectedItemContainer is NavigationViewItem selectedItem)
        {
            _selectedWorkspaceItem = selectedItem;
        }
        ShowWorkspace(args.SelectedItemContainer?.Tag?.ToString());
    }

    private void ShowWorkspace(string? section)
    {
        WorkspaceContent.Content = section switch
        {
            "statistics" => _proxyTrafficView,
            "connectionAnalytics" => _connectionAnalyticsView,
            "quota" => _quotaView,
            _ => _proxyTrafficView,
        };
    }

    private void ViewModel_ConfigurationValidated()
    {
        WorkspaceNavigation.SelectedItem = StatisticsNavigationItem;
        ShowWorkspace("statistics");
    }

    private void ResizeWindow()
    {
        var windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(this);
        var windowId = Win32Interop.GetWindowIdFromWindow(windowHandle);
        var appWindow = AppWindow.GetFromWindowId(windowId)
            ?? throw new InvalidOperationException("无法取得 WinUI 主窗口对应的 AppWindow。");
        WindowsIconAssets.ApplyApplicationIcon(appWindow);
        appWindow.Resize(new SizeInt32(1080, 680));
    }
}
