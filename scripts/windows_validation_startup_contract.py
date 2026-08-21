"""定义 Windows 登录后启动静态门禁使用的增量契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = ROOT / "platform" / "windows" / "MihomoMeter.Windows.App"

STARTUP_REQUIRED_REPOSITORY_FILES = (
    "docs/登录后启动实现契约.md",
    "scripts/windows_validation_startup_contract.py",
)

STARTUP_REQUIRED_APP_FILES = (
    "Infrastructure/Startup/StartupRegistrationService.cs",
    "Lifecycle/StartupActivation.cs",
    "Presentation/GeneralSettingsView.xaml",
    "Presentation/GeneralSettingsView.xaml.cs",
    "Presentation/StartupSettingsViewModel.cs",
)

STARTUP_REQUIRED_CODE_MARKERS = {
    ROOT / "docs/登录后启动实现契约.md": (
        "SMAppService.mainApp",
        "CurrentVersion\\Run",
        "--startup",
        "默认关闭",
    ),
    APP_ROOT / "Infrastructure/Startup/StartupRegistrationService.cs": (
        "RegistryHive.CurrentUser",
        "RegistryView.Registry64",
        "CurrentVersion\\Run",
        'RunValueName = "Mihomo Meter"',
        'StartupArgument = "--startup"',
        "EnabledForDifferentExecutable",
    ),
    APP_ROOT / "Lifecycle/StartupActivation.cs": (
        "StartupRegistrationService.StartupArgument",
        "IsStartupLaunch",
    ),
    APP_ROOT / "Presentation/StartupSettingsViewModel.cs": (
        "CanRepairRegistration",
        "RegisterCurrentExecutable",
        "Unregister",
    ),
    APP_ROOT / "Presentation/GeneralSettingsView.xaml": (
        'Text="通用"',
        'Header="登录后启动 Mihomo Meter"',
        'Content="改为当前程序"',
        "不会创建服务或计划任务",
    ),
}
