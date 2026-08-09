"""定义 Windows W3 公开分发静态门禁使用的增量契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

DISTRIBUTION_REQUIRED_REPOSITORY_FILES = (
    "docs/Windows分发实现契约.md",
    "docs/Windows阶段W3-0实机指南.md",
    "docs/Windows阶段W3-1实机指南.md",
    "platform/windows/installer/MihomoMeter.InstallDirectory.nsh",
    "platform/windows/installer/MihomoMeter.nsi",
    "scripts/build_windows_installer.ps1",
    "scripts/package_windows.ps1",
    "scripts/windows_validation_distribution_contract.py",
)

DISTRIBUTION_REQUIRED_CODE_MARKERS = {
    ROOT / ".github/workflows/windows.yml": (
        "WINDOWS_PREVIEW_VERSION",
        "NSIS_COMPILER_PATH",
        "inputs.version || '0.0.0'",
        "choco install nsis --version=3.12.0",
        "NSIS\\makensis.exe",
        '-MakeNsisPath "$env:NSIS_COMPILER_PATH"',
        "mihomo-meter-windows-w3-preview-${{ env.WINDOWS_PREVIEW_VERSION }}-${{ github.sha }}",
        ".codex-tmp/windows-package",
        "scripts/build_windows_installer.ps1",
        "scripts/package_windows.ps1",
        "scripts/windows_validation_distribution_contract.py",
        "docs/Windows阶段W3-0实机指南.md",
        "docs/Windows阶段W3-1实机指南.md",
        "docs/Windows分发实现契约.md",
        "contents: read",
    ),
    ROOT / "scripts/validate_windows.ps1": (
        '[string]$Version = "0.0.0"',
        '[string]$MakeNsisPath = "makensis.exe"',
        ".codex-tmp/windows-publish",
        ".codex-tmp/windows-package",
        '"-p:Version=$Version"',
        '"-p:FileVersion=${Version}.0"',
        '"-p:AssemblyVersion=${Version}.0"',
        "package_windows.ps1",
        "-MakeNsisPath $MakeNsisPath",
        "Windows 当前阶段必须复用系统 winsqlite3.dll",
    ),
    ROOT / "scripts/package_windows.ps1": (
        "Mihomo-Meter-$Version-windows-x64-portable.zip",
        "Mihomo-Meter-$Version-windows-x64-setup.exe",
        "SHA256SUMS",
        "Mihomo Meter/",
        "windows-package-payload",
        "build_windows_installer.ps1",
        "1980-01-01T00:00:00Z",
        "Get-FileHash",
        "MihomoMeter.Windows.App.exe",
        "settings.json",
        "traffic.sqlite3",
        "quota.sqlite3",
        "connection-analytics.sqlite3",
        '".mihomo-meter-install"',
        '".pdb"',
    ),
    ROOT / "scripts/build_windows_installer.ps1": (
        "platform/windows/installer/MihomoMeter.nsi",
        '"/INPUTCHARSET",\n    "UTF8",',
        '"/DAPP_VERSION=$Version"',
        '"/DPAYLOAD_DIRECTORY=$PayloadDirectory"',
        '"/DOUTPUT_FILE=$OutputPath"',
        "FileVersionInfo",
    ),
    ROOT / "platform/windows/installer/MihomoMeter.nsi": (
        "RequestExecutionLevel user",
        "AllowRootDirInstall false",
        '$LOCALAPPDATA\\Programs\\Mihomo Meter',
        '$LOCALAPPDATA\\HongXunPan\\MihomoMeter',
        "SetShellVarContext current",
        "SetRegView 64",
        "com.HongXunPan.MihomoMeter",
        "MihomoMeter.InstallDirectory.nsh",
        "MUI_PAGE_DIRECTORY",
        "Microsoft YaHei UI",
        "ReadRegStr $ExistingInstallDirectory HKCU",
        "PRODUCT_INSTALL_MARKER",
        "WriteUninstaller",
        "CreateShortcut",
        "Call EnsureApplicationStopped",
        "Call un.EnsureApplicationStopped",
        "RMDir /r \"$INSTDIR\"",
    ),
    ROOT / "platform/windows/installer/MihomoMeter.InstallDirectory.nsh": (
        "ValidateFreshInstallDirectory",
        "EnsureInstallDirectoryOutsideData",
        "IsOwnedInstallDirectory",
        "EnsureExistingInstallDirectoryOwned",
        "PrepareInstallDirectoryPage",
        "ValidateInstallDirectoryPage",
        "GetTempFileName",
        "FindFirst",
        "PRODUCT_DEFAULT_INSTALL_DIRECTORY",
        "PRODUCT_INSTALL_MARKER",
    ),
    ROOT / "platform/windows/MihomoMeter.Windows.App/MainWindow.xaml.cs": (
        "Mihomo Meter · Windows W3-1",
    ),
    ROOT / "README.md": (
        "Windows W3-0 已通过",
        "Windows W3-0",
        "Windows W3-1",
        "Windows分发实现契约.md",
    ),
}


def validate_distribution_contract(errors: list[str]) -> None:
    installer = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (
            ROOT / "platform/windows/installer/MihomoMeter.nsi",
            ROOT / "platform/windows/installer/MihomoMeter.InstallDirectory.nsh",
        )
    )
    forbidden_markers = (
        "RequestExecutionLevel admin",
        "SetShellVarContext all",
        "HKLM",
        "$PROGRAMFILES",
        "$DESKTOP",
        "taskkill",
    )
    for marker in forbidden_markers:
        if marker.lower() in installer.lower():
            errors.append(f"Windows W3-1 安装器不得包含越界标记：{marker}")

    for line in installer.splitlines():
        normalized = line.strip().lower()
        deletes_directory = normalized.startswith(("rmdir ", "delete "))
        targets_user_data = (
            "product_data_directory" in normalized
            or "$localappdata\\hongxunpan\\mihomometer" in normalized
        )
        if deletes_directory and targets_user_data:
            errors.append("Windows W3-1 安装器不得删除用户数据目录。")
