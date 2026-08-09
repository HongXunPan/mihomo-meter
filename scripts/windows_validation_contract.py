"""定义 Windows 静态门禁使用的工程契约。"""

from pathlib import Path

from windows_validation_quota_contract import (
    QUOTA_CORE_PACKAGES,
    QUOTA_REQUIRED_APP_FILES,
    QUOTA_REQUIRED_CODE_MARKERS,
    QUOTA_REQUIRED_CORE_FILES,
    QUOTA_REQUIRED_REPOSITORY_FILES,
    QUOTA_REQUIRED_TEST_FILES,
)
from windows_validation_connection_contract import (
    CONNECTION_REQUIRED_APP_FILES,
    CONNECTION_REQUIRED_CODE_MARKERS,
    CONNECTION_REQUIRED_CORE_FILES,
    CONNECTION_REQUIRED_REPOSITORY_FILES,
    CONNECTION_REQUIRED_TEST_FILES,
)
from windows_validation_distribution_contract import (
    DISTRIBUTION_REQUIRED_CODE_MARKERS,
    DISTRIBUTION_REQUIRED_REPOSITORY_FILES,
)


ROOT = Path(__file__).resolve().parents[1]
WINDOWS_ROOT = ROOT / "platform" / "windows"
APP_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.App"
CORE_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.Core"
TEST_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.Tests"
APP_PROJECT = APP_ROOT / "MihomoMeter.Windows.App.csproj"
CORE_PROJECT = CORE_ROOT / "MihomoMeter.Windows.Core.csproj"
TEST_PROJECT = TEST_ROOT / "MihomoMeter.Windows.Tests.csproj"
SOLUTION_FILE = WINDOWS_ROOT / "MihomoMeter.Windows.slnx"

REQUIRED_REPOSITORY_FILES = (
    ".github/workflows/windows.yml",
    "docs/Windows工程代码技术选型.md",
    "docs/Windows阶段W1实机指南.md",
    "docs/Windows阶段W2A实机指南.md",
    "docs/Windows阶段W2B实机指南.md",
    "scripts/validate_windows.ps1",
    "scripts/windows_validation_contract.py",
    "scripts/windows_validation_notification_area_contract.py",
) + QUOTA_REQUIRED_REPOSITORY_FILES
REQUIRED_REPOSITORY_FILES += CONNECTION_REQUIRED_REPOSITORY_FILES
REQUIRED_REPOSITORY_FILES += DISTRIBUTION_REQUIRED_REPOSITORY_FILES

EXPECTED_APP_PROPERTIES = {
    "TargetFramework": "net10.0-windows10.0.19041.0",
    "TargetPlatformMinVersion": "10.0.19041.0",
    "PlatformTarget": "x64",
    "WindowsPackageType": "None",
    "WindowsAppSDKSelfContained": "true",
    "SelfContained": "true",
    "PublishSingleFile": "false",
    "PublishTrimmed": "false",
    "TreatWarningsAsErrors": "true",
}

EXPECTED_APP_PACKAGES = {
    "Microsoft.Windows.SDK.BuildTools": "10.0.28000.2526",
    "Microsoft.WindowsAppSDK": "2.3.1",
    "SQLitePCLRaw.bundle_winsqlite3": "2.1.11",
}

EXPECTED_CORE_PACKAGES = {
    "Microsoft.Data.Sqlite.Core": "10.0.10",
    **QUOTA_CORE_PACKAGES,
}

EXPECTED_TEST_PACKAGES = {
    "SQLitePCLRaw.bundle_winsqlite3": "2.1.11",
}

EXPECTED_SOLUTION_PROJECTS = {
    "MihomoMeter.Windows.App/MihomoMeter.Windows.App.csproj",
    "MihomoMeter.Windows.Core/MihomoMeter.Windows.Core.csproj",
    "MihomoMeter.Windows.Tests/MihomoMeter.Windows.Tests.csproj",
}

REQUIRED_APP_FILES = (
    "App.xaml",
    "App.xaml.cs",
    "Program.cs",
    "MainWindow.xaml",
    "MainWindow.xaml.cs",
    "app.manifest",
    "Diagnostics/StartupConsoleReporter.cs",
    "Infrastructure/Configuration/JsonControllerAddressStore.cs",
    "Infrastructure/Credentials/CredentialManagerSecretStore.cs",
    "Infrastructure/WindowsAppServices.cs",
    "Infrastructure/Statistics/TrafficLedgerLocation.cs",
    "Infrastructure/Statistics/WindowsSqliteProvider.cs",
    "Lifecycle/ActivationRouter.cs",
    "Lifecycle/WindowLifecycleController.cs",
    "Lifecycle/NotificationAreaController.cs",
    "Lifecycle/NotificationAreaController.Commands.cs",
    "Lifecycle/NotificationAreaMenu.cs",
    "Lifecycle/NotificationAreaMenu.CommandIds.cs",
    "Lifecycle/NotificationAreaMenu.Tasks.cs",
    "Lifecycle/FloatingWidgetController.cs",
    "Lifecycle/FloatingWidgetPainter.cs",
    "Lifecycle/FloatingWidgetPlacement.cs",
    "Lifecycle/FloatingWidgetWindow.cs",
    "Interop/ShellNativeMethods.cs",
    "Interop/FloatingWidgetNativeMethods.cs",
    "Presentation/MainWindowViewModel.cs",
    "Presentation/NotificationAreaStatisticsController.cs",
    "Presentation/ProxyDailyTrafficChartView.xaml",
    "Presentation/ProxyDailyTrafficChartView.xaml.cs",
    "Presentation/RealtimeMonitoringView.xaml",
    "Presentation/RealtimeMonitoringView.xaml.cs",
    "Presentation/TrafficDisplayFormatter.cs",
    "Presentation/TrafficStatisticsWorkspaceModels.cs",
    "Presentation/TrafficStatisticsWorkspaceView.xaml",
    "Presentation/TrafficStatisticsWorkspaceView.xaml.cs",
    "Presentation/TrafficStatisticsWorkspaceViewModel.cs",
    "Presentation/TrafficStatisticsWorkspaceViewModel.Projection.cs",
) + QUOTA_REQUIRED_APP_FILES
REQUIRED_APP_FILES += CONNECTION_REQUIRED_APP_FILES

REQUIRED_CORE_FILES = (
    "Domain/ControllerEndpoint.cs",
    "Domain/TrafficMeasurement.cs",
    "Domain/TrafficLedgerObservation.cs",
    "Domain/TrafficStatistics.cs",
    "Domain/TrafficIntervals.cs",
    "Domain/ProxyClassifier.cs",
    "Domain/ConnectionDeltaTracker.cs",
    "Domain/TrafficRateAggregator.cs",
    "Application/ReconnectBackoff.cs",
    "Application/ControllerConfiguration.cs",
    "Application/TrafficMeasurementSession.cs",
    "Application/TrafficRateDisplayState.cs",
    "Application/TrafficMonitorState.cs",
    "Application/TrafficMonitoringCoordinator.cs",
    "Application/TrafficMonitoringStream.cs",
    "Application/TrafficStatisticsRecording.cs",
    "Application/TrafficStatisticsCoordinator.cs",
    "Application/TrafficStatisticsQuickTaskProjection.cs",
    "Application/TrafficStatisticsWorkspaceProjection.cs",
    "Infrastructure/Mihomo/ConnectionMessageAssembler.cs",
    "Infrastructure/Mihomo/ConnectionSnapshotCollector.cs",
    "Infrastructure/Mihomo/MihomoControllerClient.cs",
    "Infrastructure/Mihomo/MihomoControllerModels.cs",
    "Infrastructure/Statistics/TrafficLedgerRuntimeState.cs",
    "Infrastructure/Statistics/TrafficLedgerSchema.cs",
    "Infrastructure/Statistics/TrafficLedgerPersistence.cs",
    "Infrastructure/Statistics/TrafficDailyPersistence.cs",
    "Infrastructure/Statistics/TrafficIntervalPersistence.cs",
    "Infrastructure/Statistics/TrafficLedgerMaintenancePersistence.cs",
    "Infrastructure/Statistics/TrafficLedgerStorageValues.cs",
    "Infrastructure/Statistics/SQLiteTrafficLedger.cs",
    "Infrastructure/Statistics/SQLiteTrafficLedger.Intervals.cs",
    "Infrastructure/Statistics/SQLiteTrafficLedger.Snapshot.cs",
    "Infrastructure/Statistics/SQLiteTrafficLedger.Transitions.cs",
    "Infrastructure/Statistics/TrafficStatisticsException.cs",
    "Properties/AssemblyInfo.cs",
) + QUOTA_REQUIRED_CORE_FILES
REQUIRED_CORE_FILES += CONNECTION_REQUIRED_CORE_FILES

REQUIRED_TEST_FILES = (
    "ControllerEndpointTests.cs",
    "MihomoControllerModelsTests.cs",
    "ProxyClassifierTests.cs",
    "Properties/AssemblyInfo.cs",
    "ConnectionDeltaTrackerTests.cs",
    "ConnectionMessageAssemblerTests.cs",
    "ControllerConfigurationStoreTests.cs",
    "TrafficRateAggregatorTests.cs",
    "ReconnectBackoffTests.cs",
    "TrafficMeasurementSessionTests.cs",
    "TrafficRateDisplayStateTests.cs",
    "TrafficMonitoringCoordinatorTests.cs",
    "SQLiteTrafficLedgerTests.cs",
    "TrafficIntervalInputTests.cs",
    "TrafficIntervalLedgerTests.cs",
    "TrafficLedgerDailyAndClearTests.cs",
    "TrafficLedgerMigrationTests.cs",
    "TrafficStatisticsBoundaryTests.cs",
    "TrafficStatisticsQuickTaskProjectionTests.cs",
    "TrafficStatisticsWorkspaceProjectionTests.cs",
    "WindowsSqliteTestProvider.cs",
) + QUOTA_REQUIRED_TEST_FILES
REQUIRED_TEST_FILES += CONNECTION_REQUIRED_TEST_FILES

REQUIRED_CODE_MARKERS = {
    APP_ROOT / "MainWindow.xaml": (
        "NavigationView",
        'Content="实时监控"',
        'Content="Proxy 流量"',
        'Content="订阅余额"',
        "StatisticsNavigationItem",
        "WorkspaceContent",
        'HorizontalContentAlignment="Stretch"',
    ),
    APP_ROOT / "MainWindow.xaml.cs": (
        "new RealtimeMonitoringView",
        "new TrafficStatisticsWorkspaceView",
        "new SubscriptionQuotaWorkspaceView",
        "NotificationAreaStatisticsController",
        "ShowStatisticsWorkspace",
        "ShowQuotaWorkspace",
        "WorkspaceNavigation_SelectionChanged",
    ),
    APP_ROOT / "Program.cs": ("FindOrRegisterForKey", "RedirectActivationToAsync"),
    APP_ROOT / "Lifecycle/WindowLifecycleController.cs": (
        "args.Cancel = true",
        "sender.Hide()",
        "RequestExit",
        "await _prepareForExit()",
        "QueueStatisticsOperation",
        "RunStatisticsOperationAsync",
    ),
    APP_ROOT / "Lifecycle/NotificationAreaController.cs": (
        "ShellNotifyIcon",
        "TaskbarCreated",
        "NotifyIconModify",
        "_captureStatisticsSnapshot",
        "_captureQuotaSnapshot",
    ),
    APP_ROOT / "Lifecycle/NotificationAreaController.Commands.cs": (
        "NotificationAreaCommandKind.RefreshQuota",
        "NotificationAreaCommandKind.StopStatistics",
        "NotificationAreaCommandKind.OpenLiveConnections",
        "ResolveMenuPoint",
    ),
    APP_ROOT / "Lifecycle/NotificationAreaMenu.cs": (
        "TrackPopupMenuEx",
        "NotificationAreaCommand",
        "AppendStatisticsMenu",
        "AppendQuotaMenu",
    ),
    APP_ROOT / "Lifecycle/NotificationAreaMenu.CommandIds.cs": (
        "RegisterCommand",
        "OpenProxyConnectionsCommand = 4001",
        "OpenDirectConnectionsCommand = 4002",
    ),
    APP_ROOT / "Lifecycle/NotificationAreaMenu.Tasks.cs": (
        "TrafficStatisticsQuickTaskProjection.SlotCount",
        "StartStatisticsCommand",
        "ViewStatisticsCommandBase",
        "StopStatisticsCommandBase",
        "AdditionalCount",
    ),
    APP_ROOT / "Lifecycle/FloatingWidgetWindow.cs": (
        "WindowStyleExtendedToolWindow",
        "WindowStyleExtendedNoActivate",
    ),
    CORE_ROOT / "Domain/ControllerEndpoint.cs": (
        "127.0.0.1",
        "::1",
        "WebSocketUri",
    ),
    CORE_ROOT / "Domain/ProxyClassifier.cs": (
        "MissingCatalogEntry",
        "AmbiguousProxyType",
    ),
    CORE_ROOT / "Domain/ConnectionDeltaTracker.cs": (
        "TrafficBytes.Residual",
        "CountersReset",
    ),
    APP_ROOT / "Infrastructure/Credentials/CredentialManagerSecretStore.cs": (
        "com.HongXunPan.MihomoMeter.controller",
    ),
    APP_ROOT / "Infrastructure/Credentials/CredentialManagerBlobStore.cs": (
        "CredReadW",
        "CredWriteW",
        "CredDeleteW",
        "CredFree",
    ),
    APP_ROOT / "Infrastructure/Configuration/JsonControllerAddressStore.cs": (
        "LocalApplicationData",
        "settings.json",
        "settings.pending.json",
    ),
    APP_ROOT / "Infrastructure/WindowsAppServices.cs": (
        "AllowAutoRedirect = false",
        "UseProxy = false",
        "SQLiteTrafficLedger",
        "TrafficStatisticsCoordinator",
        "SQLiteQuotaLedger",
        "QuotaTrackingCoordinator",
        "YamlClashProfileCatalogReader",
        "MihomoActiveQuotaQueryClient",
    ),
    APP_ROOT / "Infrastructure/Statistics/TrafficLedgerLocation.cs": (
        "LocalApplicationData",
        "traffic.sqlite3",
    ),
    APP_ROOT / "Infrastructure/Statistics/WindowsSqliteProvider.cs": (
        "SQLitePCL.Batteries_V2.Init()",
    ),
    CORE_ROOT / "Infrastructure/Mihomo/MihomoControllerClient.cs": (
        'HttpUri("/version")',
        'HttpUri("/proxies")',
        "AuthenticationFailed",
        'HttpUri("/providers/proxies")',
        'HttpUri("/configs")',
    ),
    CORE_ROOT / "Infrastructure/Mihomo/ConnectionSnapshotCollector.cs": (
        'WebSocketUri("/connections", "interval=500")',
        "ConnectionMessageAssembler",
        "socket.Options.Proxy = null",
    ),
    CORE_ROOT / "Application/TrafficMonitoringStream.cs": (
        "MonitorConnectionState.Stale",
        "_policy.ReconnectAfter - _policy.StaleAfter",
        "measurement.ResetBaseline()",
    ),
    CORE_ROOT / "Application/TrafficMonitoringCoordinator.cs": (
        "Interlocked.Increment(ref _generation)",
        "IsCurrentSession",
        "SaveValidatedAsync",
        "backoff.Reset()",
        "BeginMonitoringAsync",
        "InterruptMonitoringAsync",
        "FaultIsolatedQuotaTrackingLifecycle",
    ),
    CORE_ROOT / "Application/TrafficStatisticsCoordinator.cs": (
        "_operationGate",
        "StartIntervalAsync",
        "TryInterruptAfterStatisticsFailureAsync",
    ),
    CORE_ROOT / "Application/TrafficStatisticsWorkspaceProjection.cs": (
        "TrafficStatisticsIntervalFilter",
        "FilterIntervals",
        "DailyRange",
        "TrafficDailyAxisTicks",
        "ShowsAxisLabel",
        "UploadFraction",
        "DownloadFraction",
    ),
    CORE_ROOT / "Application/TrafficStatisticsQuickTaskProjection.cs": (
        "SlotCount = 5",
        "OrderByDescending",
        "TimeZoneInfo.ConvertTime",
        "AdditionalCount",
        "Array.AsReadOnly",
    ),
    APP_ROOT / "Presentation/NotificationAreaStatisticsController.cs": (
        "TrafficStatisticsQuickTaskProjection.Project",
        "CaptureSnapshot",
        "StartSuggestedIntervalAsync",
        "StopIntervalAsync",
        "Array.AsReadOnly",
    ),
    APP_ROOT / "Presentation/TrafficStatisticsWorkspaceView.xaml": (
        "DailyChartHost",
        "StartIntervalButton_Click",
        "ClearButton_Click",
    ),
    APP_ROOT / "Presentation/ProxyDailyTrafficChartView.xaml": (
        "ChartAxisMaximumText",
        "ChartPoints",
        "AxisLabelVisibility",
        "AutomationProperties.Name",
    ),
    APP_ROOT / "Presentation/TrafficStatisticsWorkspaceView.xaml.cs": (
        "ContentDialog",
        "dialog.XamlRoot = Root.XamlRoot",
        "StartIntervalAsync",
        "RenameIntervalAsync",
        "DeleteIntervalAsync",
        "ClearAsync",
    ),
    APP_ROOT / "Presentation/TrafficStatisticsWorkspaceViewModel.cs": (
        "TrafficStatisticsCoordinator",
        "PerformOperationAsync",
        "IsCurrentSession",
    ),
    APP_ROOT / "Presentation/TrafficStatisticsWorkspaceViewModel.Projection.cs": (
        "ObservableCollection",
        "TrafficStatisticsWorkspaceProjection.FilterIntervals",
        "TrafficStatisticsWorkspaceProjection.DailyRange",
        "TrafficStatisticsWorkspaceModelFactory.ChartPoint",
        "_intervalItems[index].Apply",
        "_chartPointItems[index].Apply",
    ),
    CORE_ROOT / "Domain/TrafficIntervals.cs": (
        "TrafficIntervalStatus",
        "TrafficIntervalEndReason",
        "TrafficIntervalInput",
    ),
    CORE_ROOT / "Infrastructure/Statistics/TrafficLedgerSchema.cs": (
        "CurrentVersion = 2",
        "CREATE TABLE core_sessions",
        "CREATE TABLE traffic_buckets",
        "CREATE TABLE traffic_daily_totals",
        "CREATE TABLE traffic_intervals",
        "CREATE TABLE ledger_state",
    ),
    CORE_ROOT / "Infrastructure/Statistics/SQLiteTrafficLedger.cs": (
        "TrafficLedgerBaselineEstablished",
        "TrafficLedgerDelta",
        "TrafficLedgerCountersReset",
    ),
    CORE_ROOT / "Infrastructure/Statistics/SQLiteTrafficLedger.Intervals.cs": (
        "StartIntervalAsync",
        "StopIntervalAsync",
        "InterruptActiveIntervalsAsync",
        "Maintenance.Reset",
    ),
    CORE_ROOT / "Infrastructure/Statistics/SQLiteTrafficLedger.Snapshot.cs": (
        "AddDays(-365)",
        "RecentProxyDays",
    ),
    CORE_ROOT / "Infrastructure/Statistics/SQLiteTrafficLedger.Transitions.cs": (
        "TrafficCategory.Unknown",
        "counter_reset",
    ),
    CORE_ROOT / "Infrastructure/Statistics/TrafficIntervalPersistence.cs": (
        "status = 'completed'",
        "status = 'interrupted'",
        "statistics_unavailable",
    ),
    **QUOTA_REQUIRED_CODE_MARKERS,
    **CONNECTION_REQUIRED_CODE_MARKERS,
    **DISTRIBUTION_REQUIRED_CODE_MARKERS,
}

FORBIDDEN_PROJECT_MARKERS = (
    "Microsoft.EntityFrameworkCore",
    "System.Data.SQLite",
    "SQLitePCLRaw.bundle_e_sqlite3",
)

FORBIDDEN_CODE_MARKERS = (
    "RegistryKey",
    "EventLog",
    "WindowsIdentity.Impersonate",
    "Clash Verge",
    "W0ConsoleReporter",
    "record ControllerConfiguration",
)
