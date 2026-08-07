"""定义 Windows 静态门禁使用的工程契约。"""

from pathlib import Path


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
    "scripts/validate_windows.ps1",
    "scripts/windows_validation_contract.py",
)

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
    "Lifecycle/FloatingWidgetController.cs",
    "Lifecycle/FloatingWidgetPainter.cs",
    "Lifecycle/FloatingWidgetPlacement.cs",
    "Lifecycle/FloatingWidgetWindow.cs",
    "Interop/ShellNativeMethods.cs",
    "Interop/FloatingWidgetNativeMethods.cs",
    "Presentation/MainWindowViewModel.cs",
)

REQUIRED_CORE_FILES = (
    "Domain/ControllerEndpoint.cs",
    "Domain/TrafficMeasurement.cs",
    "Domain/TrafficLedgerObservation.cs",
    "Domain/TrafficStatistics.cs",
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
    "Infrastructure/Mihomo/ConnectionMessageAssembler.cs",
    "Infrastructure/Mihomo/ConnectionSnapshotCollector.cs",
    "Infrastructure/Mihomo/MihomoControllerClient.cs",
    "Infrastructure/Mihomo/MihomoControllerModels.cs",
    "Infrastructure/Statistics/TrafficLedgerRuntimeState.cs",
    "Infrastructure/Statistics/TrafficLedgerSchema.cs",
    "Infrastructure/Statistics/TrafficLedgerPersistence.cs",
    "Infrastructure/Statistics/TrafficLedgerStorageValues.cs",
    "Infrastructure/Statistics/SQLiteTrafficLedger.cs",
    "Infrastructure/Statistics/TrafficStatisticsException.cs",
    "Properties/AssemblyInfo.cs",
)

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
    "TrafficStatisticsBoundaryTests.cs",
    "WindowsSqliteTestProvider.cs",
)

REQUIRED_CODE_MARKERS = {
    APP_ROOT / "Program.cs": ("FindOrRegisterForKey", "RedirectActivationToAsync"),
    APP_ROOT / "Lifecycle/WindowLifecycleController.cs": (
        "args.Cancel = true",
        "sender.Hide()",
        "RequestExit",
        "await _prepareForExit()",
    ),
    APP_ROOT / "Lifecycle/NotificationAreaController.cs": (
        "ShellNotifyIcon",
        "TaskbarCreated",
        "NotifyIconModify",
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
    ),
    CORE_ROOT / "Infrastructure/Statistics/TrafficLedgerSchema.cs": (
        "CREATE TABLE core_sessions",
        "CREATE TABLE traffic_buckets",
        "CREATE TABLE traffic_daily_totals",
        "CREATE TABLE ledger_state",
    ),
    CORE_ROOT / "Infrastructure/Statistics/SQLiteTrafficLedger.cs": (
        "TrafficLedgerBaselineEstablished",
        "TrafficLedgerDelta",
        "TrafficLedgerCountersReset",
        "TrafficCategory.Unknown",
        "AddDays(-365)",
    ),
}

FORBIDDEN_PROJECT_MARKERS = (
    "Microsoft.EntityFrameworkCore",
    "System.Data.SQLite",
    "SQLitePCLRaw.bundle_e_sqlite3",
    'PackageReference Include="Yaml',
)

FORBIDDEN_CODE_MARKERS = (
    "RegistryKey",
    "EventLog",
    "WindowsIdentity.Impersonate",
    "Clash Verge",
    "W0ConsoleReporter",
    "record ControllerConfiguration",
)
