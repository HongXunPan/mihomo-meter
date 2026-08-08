"""定义 Windows W2C 订阅配额静态门禁使用的增量契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WINDOWS_ROOT = ROOT / "platform" / "windows"
APP_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.App"
CORE_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.Core"

QUOTA_REQUIRED_REPOSITORY_FILES = (
    "docs/Windows阶段W2C实机指南.md",
    "docs/Windows订阅配额实现契约.md",
    "scripts/windows_validation_quota_contract.py",
)

QUOTA_CORE_PACKAGES = {
    "YamlDotNet": "18.1.0",
}

QUOTA_REQUIRED_APP_FILES = (
    "Infrastructure/Configuration/JsonProfileDirectoryStore.cs",
    "Infrastructure/Credentials/CredentialManagerBlobStore.cs",
    "Infrastructure/Credentials/CredentialManagerProfileFingerprintKeyStore.cs",
    "Infrastructure/Quota/QuotaLedgerLocation.cs",
    "Lifecycle/NotificationAreaMenu.Quota.cs",
    "Presentation/NotificationAreaQuotaController.cs",
    "Presentation/QuotaTrendChartView.xaml",
    "Presentation/QuotaTrendChartView.Drawing.cs",
    "Presentation/QuotaTrendChartView.xaml.cs",
    "Presentation/SubscriptionQuotaFormatter.cs",
    "Presentation/SubscriptionQuotaWorkspaceModels.cs",
    "Presentation/SubscriptionQuotaWorkspaceView.xaml",
    "Presentation/SubscriptionQuotaWorkspaceView.xaml.cs",
    "Presentation/SubscriptionQuotaWorkspaceViewModel.cs",
    "Presentation/SubscriptionQuotaWorkspaceViewModel.Projection.cs",
)

QUOTA_REQUIRED_CORE_FILES = (
    "Application/ActiveQuotaQuery.cs",
    "Application/FaultIsolatedQuotaTrackingLifecycle.cs",
    "Application/ProfileDirectory.cs",
    "Application/ProfileQuotaSchedulePolicy.cs",
    "Application/QuotaLedger.cs",
    "Application/QuotaQueryGate.cs",
    "Application/QuotaTrackingCoordinator.cs",
    "Application/QuotaTrackingCoordinator.Profiles.cs",
    "Application/QuotaTrackingCoordinator.Queries.cs",
    "Application/QuotaTrackingCoordinator.Runtime.cs",
    "Application/QuotaTrackingCoordinator.State.cs",
    "Application/QuotaTrackingState.cs",
    "Domain/ClashProfiles.cs",
    "Domain/QuotaCycles.cs",
    "Domain/QuotaRuntime.cs",
    "Domain/QuotaSubscriptions.cs",
    "Domain/QuotaTraffic.cs",
    "Domain/QuotaTrends.cs",
    "Infrastructure/Mihomo/MihomoQuotaModels.cs",
    "Infrastructure/Profile/HmacProfileUrlFingerprinter.cs",
    "Infrastructure/Profile/ProfileDirectoryObserver.cs",
    "Infrastructure/Profile/YamlClashProfileCatalogReader.cs",
    "Infrastructure/Quota/MihomoActiveQuotaQueryClient.cs",
    "Infrastructure/Quota/QuotaLedgerPersistence.cs",
    "Infrastructure/Quota/QuotaLedgerPersistence.Cycles.cs",
    "Infrastructure/Quota/QuotaLedgerPersistence.Events.cs",
    "Infrastructure/Quota/QuotaLedgerPersistence.QueryState.cs",
    "Infrastructure/Quota/QuotaLedgerPersistence.Snapshots.cs",
    "Infrastructure/Quota/QuotaLedgerPersistence.Subscriptions.cs",
    "Infrastructure/Quota/QuotaLedgerSchema.cs",
    "Infrastructure/Quota/QuotaLedgerStorageValues.cs",
    "Infrastructure/Quota/SQLiteQuotaLedger.cs",
)

QUOTA_REQUIRED_TEST_FILES = (
    "ActiveQuotaQueryContractTests.cs",
    "ProfileQuotaIdentityTests.cs",
    "QuotaDomainTests.cs",
    "QuotaLifecycleIsolationTests.cs",
    "QuotaQueryGateTests.cs",
    "SQLiteQuotaLedgerTests.cs",
)

QUOTA_REQUIRED_CODE_MARKERS = {
    ROOT / ".github/workflows/windows.yml": (
        "mihomo-meter-windows-w2c-x64-${{ github.sha }}",
        ".codex-tmp/windows-w2c-publish",
        "scripts/windows_validation_quota_contract.py",
        "docs/Windows阶段W2C实机指南.md",
    ),
    ROOT / "scripts/validate_windows.ps1": (
        ".codex-tmp/windows-w2c-publish",
        "Windows W2C 必须复用系统 winsqlite3.dll",
    ),
    APP_ROOT / "Lifecycle/NotificationAreaMenu.Quota.cs": (
        "OpenQuotaCommand",
        "RefreshQuotaCommand",
        "snapshot.Items",
        "CanRefreshAll",
    ),
    APP_ROOT / "Presentation/SubscriptionQuotaWorkspaceView.xaml": (
        "SelectDirectoryButton_Click",
        "EnableRuntimeButton_Click",
        "RefreshAllButton_Click",
        "QuotaTrendChartView",
        "ConfirmCycleButton_Click",
        "ClearButton_Click",
    ),
    APP_ROOT / "Presentation/SubscriptionQuotaWorkspaceView.xaml.cs": (
        "FolderPicker",
        "InitializeWithWindow.Initialize",
        "SetProfileDirectoryAsync",
        "ClearProfileDirectoryAsync",
    ),
    APP_ROOT / "Presentation/QuotaTrendChartView.Drawing.cs": (
        "DrawAxes",
        "Polygon",
    ),
    APP_ROOT / "Presentation/QuotaTrendChartView.xaml.cs": (
        "QuotaTrendEngine.Sample",
        "PointerMoved",
        "Polyline",
    ),
    APP_ROOT / "Presentation/SubscriptionQuotaWorkspaceViewModel.Projection.cs": (
        "ApplyStableCollection",
        "QuotaTrendChartModel",
        "CanRefreshManually",
    ),
    APP_ROOT / "Presentation/NotificationAreaQuotaController.cs": (
        "MaximumItems = 5",
        "CaptureSnapshot",
        "RefreshAllAsync",
        "Array.AsReadOnly",
    ),
    CORE_ROOT / "Infrastructure/Quota/QuotaLedgerSchema.cs": (
        "CurrentVersion = 1",
        "CREATE TABLE subscriptions",
        "CREATE TABLE quota_cycles",
        "CREATE TABLE quota_snapshots",
        "CREATE TABLE quota_events",
        "CREATE TABLE quota_query_state",
    ),
    CORE_ROOT / "Infrastructure/Quota/SQLiteQuotaLedger.cs": (
        "QuotaCycleDetector.RequiresNewCycle",
        "QuotaTrendEngine.Calculate",
        "QuotaTrendEngine.Forecast",
        "ValidateSource",
    ),
    CORE_ROOT / "Infrastructure/Profile/YamlClashProfileCatalogReader.cs": (
        "MaximumFileSize = 2 * 1_024 * 1_024",
        "FileAttributes.ReparsePoint",
        "IgnoreUnmatchedProperties",
        "profiles.yaml 包含重复 UID",
    ),
    CORE_ROOT / "Infrastructure/Profile/HmacProfileUrlFingerprinter.cs": (
        "HMACSHA256.HashData",
        "CryptographicOperations.ZeroMemory",
    ),
    CORE_ROOT / "Infrastructure/Quota/MihomoActiveQuotaQueryClient.cs": (
        "AllowAutoRedirect = false",
        "UseProxy = true",
        "new WebProxy(proxy.ProxyUri, false)",
        "MaximumRedirects = 5",
        'EndsWith(\n                "-subscription-userinfo"',
    ),
    CORE_ROOT / "Application/QuotaTrackingCoordinator.cs": (
        "RuntimeObservationInterval = TimeSpan.FromMinutes(5)",
        "QueryScheduleInterval = TimeSpan.FromSeconds(30)",
        "_lastValidatedEndpoint",
        "StopNetworkTasksAsync",
    ),
    CORE_ROOT / "Application/ProfileQuotaSchedulePolicy.cs": (
        "ManualRefreshCooldown = TimeSpan.FromSeconds(60)",
        "MaximumAutomaticRetriesPerDay = 3",
    ),
    CORE_ROOT / "Application/FaultIsolatedQuotaTrackingLifecycle.cs": (
        "IgnoreFailureAsync",
        "ControllerValidatedAsync",
        "ControllerUnavailableAsync",
    ),
    APP_ROOT
    / "Infrastructure/Credentials/CredentialManagerProfileFingerprintKeyStore.cs": (
        "com.HongXunPan.MihomoMeter.profile-fingerprint-key",
        "RandomNumberGenerator.GetBytes",
    ),
    APP_ROOT / "Infrastructure/Quota/QuotaLedgerLocation.cs": (
        "LocalApplicationData",
        "quota.sqlite3",
    ),
}
