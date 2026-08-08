"""定义 Windows W2D 连接分析静态门禁使用的增量契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WINDOWS_ROOT = ROOT / "platform" / "windows"
APP_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.App"
CORE_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.Core"

CONNECTION_REQUIRED_REPOSITORY_FILES = (
    "docs/Windows阶段W2D0实机指南.md",
    "docs/Windows阶段W2D1实机指南.md",
    "docs/Windows连接分析实现契约.md",
    "scripts/windows_validation_connection_contract.py",
)

CONNECTION_REQUIRED_APP_FILES = (
    "Lifecycle/NotificationAreaMenu.Connections.cs",
    "Presentation/LiveConnectionWorkspaceModels.cs",
    "Presentation/LiveConnectionWorkspaceView.xaml",
    "Presentation/LiveConnectionWorkspaceView.xaml.cs",
    "Presentation/LiveConnectionWorkspaceViewModel.cs",
    "Presentation/LiveConnectionWorkspaceViewModel.Projection.cs",
    "Presentation/NotificationAreaConnectionController.cs",
    "Presentation/ProxyTrafficWorkspaceView.xaml",
    "Presentation/ProxyTrafficWorkspaceView.xaml.cs",
)

CONNECTION_REQUIRED_CORE_FILES = (
    "Domain/ConnectionAttributionCoverage.cs",
    "Domain/ConnectionMetadata.cs",
    "Domain/ConnectionRateAggregator.cs",
    "Application/LiveConnectionProjection.cs",
    "Infrastructure/Mihomo/ConnectionMetadataJsonConverter.cs",
    "Infrastructure/Mihomo/TolerantDateTimeOffsetJsonConverter.cs",
)

CONNECTION_REQUIRED_TEST_FILES = (
    "ConnectionAttributionCoverageTests.cs",
    "ConnectionRateAggregatorTests.cs",
    "LiveConnectionProjectionTests.cs",
)

CONNECTION_REQUIRED_CODE_MARKERS = {
    ROOT / ".github/workflows/windows.yml": (
        "mihomo-meter-windows-w2d-x64-${{ github.sha }}",
        ".codex-tmp/windows-w2d-publish",
        "scripts/windows_validation_connection_contract.py",
        "docs/Windows阶段W2D0实机指南.md",
        "docs/Windows阶段W2D1实机指南.md",
        "docs/Windows连接分析实现契约.md",
    ),
    ROOT / "scripts/validate_windows.ps1": (
        ".codex-tmp/windows-w2d-publish",
        "Windows 当前阶段必须复用系统 winsqlite3.dll",
    ),
    APP_ROOT / "MainWindow.xaml.cs": (
        "Mihomo Meter · Windows W2D",
        "new LiveConnectionWorkspaceViewModel",
        "new ProxyTrafficWorkspaceView",
        "ShowLiveConnectionsWorkspace",
    ),
    APP_ROOT / "Presentation/RealtimeMonitoringView.xaml": (
        "连接分析覆盖率",
        "ProxyConnectionSampleText",
        "HostnameIdentifiedText",
        "ApplicationIdentifiedText",
        "FullyIdentifiedText",
        "实时页仅展示脱敏主机名与应用名称",
    ),
    APP_ROOT / "Presentation/MainWindowViewModel.cs": (
        "snapshot.AttributionCoverage",
        "AttributionMetric",
    ),
    CORE_ROOT / "Domain/ConnectionAttributionCoverage.cs": (
        "ConnectionMetadataAvailability",
        "ConnectionAttributionCoverageTracker",
        "StringComparer.Ordinal",
        "previousAvailability.HasHostname",
        "previousAvailability.HasApplication",
    ),
    CORE_ROOT / "Domain/ConnectionMetadata.cs": (
        "ConnectionMetadata",
        "UnknownApplication",
        "UnknownHostname",
        "MihomoProcessMatchingMode",
    ),
    CORE_ROOT / "Domain/ConnectionRateAggregator.cs": (
        "EstablishBaseline",
        "RemoveInactiveConnections",
        "smoothingWindowCount",
        "LiveConnections",
    ),
    CORE_ROOT / "Application/LiveConnectionProjection.cs": (
        "LiveConnectionRoute",
        "LiveConnectionViewMode",
        "TopSlotCount = 5",
        "ApplicationIdentificationDiagnostic",
    ),
    CORE_ROOT / "Infrastructure/Mihomo/ConnectionMetadataJsonConverter.cs": (
        "MaximumMetadataBytes = 2_048",
        "IPAddress.TryParse",
        "Encoding.UTF8.GetByteCount",
        "JsonDocument.ParseValue",
        "OutermostApplicationBundleName",
    ),
    CORE_ROOT / "Infrastructure/Mihomo/MihomoControllerModels.cs": (
        "ConnectionMetadataJsonConverter",
        "TolerantDateTimeOffsetJsonConverter",
        "connection.Metadata",
        "connection.StartedAt",
        "find-process-mode",
    ),
    CORE_ROOT / "Application/TrafficMeasurementSession.cs": (
        "ConnectionAttributionCoverageTracker",
        "TrafficCategory.Proxy",
        "_proxyConnectionRates",
        "_directConnectionRates",
        "_attributionCoverageTracker.Reset()",
    ),
    CORE_ROOT / "Application/TrafficMonitoringStream.cs": (
        "AttributionCoverage: result.AttributionCoverage",
        "ProxyConnections: result.LiveProxyConnections",
        "DirectConnections: result.LiveDirectConnections",
    ),
    CORE_ROOT / "Application/TrafficMonitoringCoordinator.cs": (
        "TryFetchProcessMatchingModeAsync",
        "FetchProcessConfigurationAsync",
    ),
    APP_ROOT / "Presentation/ProxyTrafficWorkspaceView.xaml": (
        "流量统计",
        "实时连接",
        "WorkspaceContent",
    ),
    APP_ROOT / "Presentation/LiveConnectionWorkspaceView.xaml": (
        "ViewModel.ContextTitle",
        "搜索应用或域名",
        "实时速率",
        "不显示或持久化连接 ID、完整进程路径、目标 IP、端口、节点、规则和链路",
    ),
    APP_ROOT / "Presentation/LiveConnectionWorkspaceViewModel.Projection.cs": (
        ".Connections(SourceConnections, SearchText)",
        ".Groups(SourceConnections, SelectedMode.Mode, SearchText)",
        "_connections[index].Apply",
        "_groups[index].Apply",
        "ApplicationIdentificationDiagnostic.Create",
    ),
    APP_ROOT / "Presentation/NotificationAreaConnectionController.cs": (
        "LiveConnectionProjection.TopSlots",
        "Array.AsReadOnly",
        "CaptureSnapshot",
    ),
    APP_ROOT / "Lifecycle/NotificationAreaMenu.Connections.cs": (
        "TopSlotCount",
        "活动 Proxy Top 5",
        "活动直连 Top 5",
        "OpenLiveConnections",
    ),
}
