"""定义 Windows W3-2 更新与稳定发布静态契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WINDOWS_ROOT = ROOT / "platform/windows"
APP_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.App"
CORE_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.Core"
TEST_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.Tests"

RELEASE_REQUIRED_REPOSITORY_FILES = (
    ".github/workflows/download-count.yml",
    ".github/workflows/release.yml",
    "docs/Windows阶段W3-2实机指南.md",
    "scripts/inherited_release_descriptor.py",
    "scripts/release_platform_descriptors.py",
    "scripts/test_release_platform_descriptors.py",
    "scripts/validate_release_candidate.py",
    "scripts/windows_validation_release_contract.py",
)

RELEASE_REQUIRED_APP_FILES = (
    "Presentation/WindowsUpdateWorkspaceView.xaml",
    "Presentation/WindowsUpdateWorkspaceView.xaml.cs",
    "Presentation/WindowsUpdateWorkspaceViewModel.cs",
)

RELEASE_REQUIRED_CORE_FILES = (
    "Application/WindowsUpdateCheck.cs",
    "Domain/ReleaseVersion.cs",
    "Infrastructure/Update/GitHubWindowsReleaseClient.cs",
)

RELEASE_REQUIRED_TEST_FILES = (
    "GitHubWindowsReleaseClientTests.cs",
    "ReleaseVersionTests.cs",
    "WindowsUpdateCheckerTests.cs",
)

RELEASE_REQUIRED_CODE_MARKERS = {
    ROOT / ".github/workflows/download-count.yml": (
        "发布 Mihomo Meter",
    ),
    ROOT / ".github/workflows/windows.yml": (
        "scripts/inherited_release_descriptor.py",
    ),
    APP_ROOT / "MainWindow.xaml": (
        'IsSettingsVisible="True"',
    ),
    APP_ROOT / "MainWindow.xaml.cs": (
        "WindowsUpdateWorkspaceViewModel",
        'settingsItem.Content = "关于与更新"',
        '"updates" => _updateView',
        "Mihomo Meter · Windows W3-2",
    ),
    APP_ROOT / "Infrastructure/WindowsAppServices.cs": (
        "controllerHttpClient",
        "updateHttpClient",
        "UseProxy = false",
        "UseProxy = true",
        "GitHubWindowsReleaseClient",
        "WindowsUpdateChecker",
    ),
    APP_ROOT / "Presentation/WindowsUpdateWorkspaceView.xaml": (
        'Text="关于与更新"',
        'Content="打开发布页面"',
        "ViewModel.CanCheck",
    ),
    APP_ROOT / "Presentation/WindowsUpdateWorkspaceView.xaml.cs": (
        "global::Windows.System.Launcher.LaunchUriAsync",
    ),
    CORE_ROOT / "Domain/ReleaseVersion.cs": (
        "TryParse",
        "FromAssemblyVersion",
        "CompareTo",
    ),
    CORE_ROOT / "Application/WindowsUpdateCheck.cs": (
        "WindowsUpdateAvailability",
        "WindowsReleaseQueryFailureCategory",
        "WindowsUpdateChecker",
        "_activeCheck",
    ),
    CORE_ROOT / "Infrastructure/Update/GitHubWindowsReleaseClient.cs": (
        "releases/latest/download/windows-release.json",
        "MaximumDescriptorBytes",
        ".githubusercontent.com",
        "InvalidDescriptor",
        "Windows x64 安装版",
        "Windows x64 便携版",
    ),
    ROOT / "scripts/release_platform_descriptors.py": (
        "macos-release.json",
        "windows-release.json",
        "Apple Silicon Mac（M 系列芯片）",
        "Windows x64 安装版",
        "validate_release_snapshot",
        "verify_descriptor_assets",
    ),
    ROOT / "scripts/inherited_release_descriptor.py": (
        "generate_inherited_descriptor",
        "load_release_checksums",
        "load_release_asset_names",
        "descriptor_from_hashes",
    ),
    ROOT / "scripts/validate_release_candidate.py": (
        "候选 Release 资产列表与发布平台不一致",
        "validate_release_snapshot",
        "validate_checksums",
        "actual_body.startswith(expected_body_prefix)",
    ),
    ROOT / ".github/workflows/release.yml": (
        "platform:",
        "release_mode:",
        "contents: read",
        "contents: write",
        "release_platform_descriptors.py",
        "macos-release.json",
        "windows-release.json",
        "actions/download-artifact@v7",
        "inputs.release_mode == 'draft'",
        "stable 模式只允许提升同版本 draft Release。",
        "inherited_release_descriptor.py generate",
        "--pattern SHA256SUMS",
        "grep -Fxq macos-release.json",
        "validate_release_candidate.py",
        "--draft",
        "--draft=false --latest",
    ),
}


def validate_release_contract(errors: list[str]) -> None:
    workflow_path = ROOT / ".github/workflows/release.yml"
    if not workflow_path.is_file():
        return

    workflow = workflow_path.read_text(encoding="utf-8")
    if workflow.count("contents: write") != 1:
        errors.append("正式发布工作流必须且只能把 contents: write 授予最终发布任务。")
    if "permissions:\n  contents: read" not in workflow:
        errors.append("正式发布工作流默认权限必须为 contents: read。")

    windows_workflow = (ROOT / ".github/workflows/windows.yml").read_text(encoding="utf-8")
    if windows_workflow.count('"scripts/inherited_release_descriptor.py"') != 2:
        errors.append("旧 Release 描述引导脚本必须同时触发 Windows PR 与 main 门禁。")
    for forbidden in (
        "PERSONAL_ACCESS_TOKEN",
        "GH_PAT",
        "RequestExecutionLevel admin",
        "windows-latest",
    ):
        if forbidden in workflow:
            errors.append(f"W3-2 正式发布不得包含越界标记：{forbidden}")

    update_code = (
        CORE_ROOT / "Infrastructure/Update/GitHubWindowsReleaseClient.cs"
    ).read_text(encoding="utf-8")
    for forbidden in (
        "ControllerEndpoint",
        "CredentialManager",
        "settings.json",
        "Process.Start",
    ):
        if forbidden in update_code:
            errors.append(f"Windows 更新查询不得耦合敏感或越界能力：{forbidden}")
