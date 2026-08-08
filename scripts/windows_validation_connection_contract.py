"""定义 Windows W2D 连接分析静态门禁使用的增量契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WINDOWS_ROOT = ROOT / "platform" / "windows"
APP_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.App"
CORE_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.Core"

CONNECTION_REQUIRED_REPOSITORY_FILES = (
    "docs/Windows阶段W2D0实机指南.md",
    "docs/Windows连接分析实现契约.md",
    "scripts/windows_validation_connection_contract.py",
)

CONNECTION_REQUIRED_APP_FILES: tuple[str, ...] = ()

CONNECTION_REQUIRED_CORE_FILES = (
    "Domain/ConnectionAttributionCoverage.cs",
    "Infrastructure/Mihomo/ConnectionMetadataAvailabilityJsonConverter.cs",
)

CONNECTION_REQUIRED_TEST_FILES = (
    "ConnectionAttributionCoverageTests.cs",
)

CONNECTION_REQUIRED_CODE_MARKERS = {
    ROOT / ".github/workflows/windows.yml": (
        "mihomo-meter-windows-w2d-x64-${{ github.sha }}",
        ".codex-tmp/windows-w2d-publish",
        "scripts/windows_validation_connection_contract.py",
        "docs/Windows阶段W2D0实机指南.md",
        "docs/Windows连接分析实现契约.md",
    ),
    ROOT / "scripts/validate_windows.ps1": (
        ".codex-tmp/windows-w2d-publish",
        "Windows 当前阶段必须复用系统 winsqlite3.dll",
    ),
    APP_ROOT / "MainWindow.xaml.cs": (
        "Mihomo Meter · Windows W2D",
    ),
    APP_ROOT / "Presentation/RealtimeMonitoringView.xaml": (
        "连接分析 W2D-0",
        "ProxyConnectionSampleText",
        "HostnameIdentifiedText",
        "ApplicationIdentifiedText",
        "FullyIdentifiedText",
        "不会展示、记录或持久化主机名、进程名、进程路径和连接 ID",
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
    CORE_ROOT / "Infrastructure/Mihomo/ConnectionMetadataAvailabilityJsonConverter.cs": (
        "MaximumMetadataBytes = 2_048",
        "IPAddress.TryParse",
        "Encoding.UTF8.GetByteCount",
        "JsonDocument.ParseValue",
    ),
    CORE_ROOT / "Infrastructure/Mihomo/MihomoControllerModels.cs": (
        "ConnectionMetadataAvailabilityJsonConverter",
        "connection.MetadataAvailability",
    ),
    CORE_ROOT / "Application/TrafficMeasurementSession.cs": (
        "ConnectionAttributionCoverageTracker",
        "TrafficCategory.Proxy",
        "_attributionCoverageTracker.Reset()",
    ),
    CORE_ROOT / "Application/TrafficMonitoringStream.cs": (
        "AttributionCoverage: result.AttributionCoverage",
    ),
}
