"""定义 Windows W3 公开分发静态门禁使用的增量契约。"""

import codecs
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NSIS_SOURCE_PATHS = (
    ROOT / "platform/windows/installer/MihomoMeter.nsi",
    ROOT / "platform/windows/installer/MihomoMeter.InstallDirectory.nsh",
)

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
        "MihomoMeter.InstallDirectory.nsh",
        "Assert-Utf8BomSource",
        "[System.IO.File]::ReadAllBytes",
        "[System.Text.UTF8Encoding]::new($true, $true)",
        "foreach ($Character in $Content.ToCharArray())",
        "$CodePoint -eq 0xFFFD",
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
        "Mihomo Meter · Windows W3-2",
    ),
    ROOT / "README.md": (
        "Windows W3-1 安装生命周期已通过",
        "Windows W3-0",
        "Windows W3-1",
        "W3-2",
        "Windows分发实现契约.md",
    ),
}


def read_nsis_source(path: Path, errors: list[str]) -> str:
    if not path.is_file():
        return ""

    raw = path.read_bytes()
    if not raw.startswith(codecs.BOM_UTF8):
        errors.append(
            f"Windows NSIS 安装器源文件必须使用带 BOM 的 UTF-8：{path.relative_to(ROOT)}"
        )

    try:
        content = raw.decode("utf-8-sig", errors="strict")
    except UnicodeDecodeError:
        errors.append(
            f"Windows NSIS 安装器源文件包含无效 UTF-8：{path.relative_to(ROOT)}"
        )
        return ""

    suspicious_code_points = sorted(
        {
            ord(character)
            for character in content
            if 0x0080 <= ord(character) <= 0x009F
            or 0x00C0 <= ord(character) <= 0x024F
            or character == "\ufffd"
        }
    )
    if suspicious_code_points:
        code_points = ", ".join(
            f"U+{code_point:04X}" for code_point in suspicious_code_points
        )
        errors.append(
            "Windows NSIS 安装器源文件疑似包含乱码字符："
            f"{path.relative_to(ROOT)}（{code_points}）"
        )

    return content


def validate_distribution_contract(errors: list[str]) -> None:
    installer = "\n".join(
        read_nsis_source(path, errors)
        for path in NSIS_SOURCE_PATHS
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
