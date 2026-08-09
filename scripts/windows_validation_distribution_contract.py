"""定义 Windows W3 公开分发静态门禁使用的增量契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

DISTRIBUTION_REQUIRED_REPOSITORY_FILES = (
    "docs/Windows分发实现契约.md",
    "docs/Windows阶段W3-0实机指南.md",
    "scripts/package_windows.ps1",
    "scripts/windows_validation_distribution_contract.py",
)

DISTRIBUTION_REQUIRED_CODE_MARKERS = {
    ROOT / ".github/workflows/windows.yml": (
        "WINDOWS_PREVIEW_VERSION",
        "mihomo-meter-windows-w3-preview-${{ env.WINDOWS_PREVIEW_VERSION }}-${{ github.sha }}",
        ".codex-tmp/windows-package",
        "scripts/package_windows.ps1",
        "scripts/windows_validation_distribution_contract.py",
        "docs/Windows阶段W3-0实机指南.md",
        "docs/Windows分发实现契约.md",
        "contents: read",
    ),
    ROOT / "scripts/validate_windows.ps1": (
        '[string]$Version = "0.0.0"',
        ".codex-tmp/windows-publish",
        ".codex-tmp/windows-package",
        '"-p:Version=$Version"',
        '"-p:FileVersion=${Version}.0"',
        '"-p:AssemblyVersion=${Version}.0"',
        "package_windows.ps1",
        "Windows 当前阶段必须复用系统 winsqlite3.dll",
    ),
    ROOT / "scripts/package_windows.ps1": (
        "Mihomo-Meter-$Version-windows-x64-portable.zip",
        "SHA256SUMS",
        "Mihomo Meter/",
        "1980-01-01T00:00:00Z",
        "Get-FileHash",
        "MihomoMeter.Windows.App.exe",
        "settings.json",
        "traffic.sqlite3",
        "quota.sqlite3",
        "connection-analytics.sqlite3",
        '".pdb"',
    ),
    ROOT / "README.md": (
        "Windows W2D-2 已通过",
        "Windows W3-0",
        "Windows分发实现契约.md",
    ),
}
