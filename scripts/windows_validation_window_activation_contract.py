"""校验 Windows 设置窗口的激活顺序与前置契约。"""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = ROOT / "platform" / "windows" / "MihomoMeter.Windows.App"
MAIN_WINDOW_FILE = APP_ROOT / "MainWindow.xaml.cs"
SETTINGS_WINDOW_CONTROLLER_FILE = (
    APP_ROOT / "Lifecycle" / "SettingsWindowController.cs"
)
WINDOW_OWNERSHIP_FILE = APP_ROOT / "Interop" / "WindowOwnershipNativeMethods.cs"


def validate_window_activation_contract(errors: list[str]) -> None:
    main_window = MAIN_WINDOW_FILE.read_text(encoding="utf-8")
    settings_branch = re.search(
        r"if \(args\.IsSettingsSelected\)\s*\{(?P<body>.*?)\n\s*return;\s*\}",
        main_window,
        re.DOTALL,
    )
    if settings_branch is None:
        errors.append("主窗口必须保留设置导航分支")
    else:
        body = settings_branch.group("body")
        restore_index = body.find(
            "WorkspaceNavigation.SelectedItem = _selectedWorkspaceItem;"
        )
        show_index = body.find("_settingsWindow.ShowConnectionSettings();")
        if restore_index < 0 or show_index < 0 or restore_index >= show_index:
            errors.append("设置导航必须先恢复工作区选择，再前置设置窗口")

    controller = SETTINGS_WINDOW_CONTROLLER_FILE.read_text(encoding="utf-8")
    required_markers = (
        "using MihomoMeter.Windows.App.Interop;",
        "private readonly nint _ownerWindowHandle;",
        "private nint _windowHandle;",
        "private void ActivateWindow()",
        "WindowOwnershipNativeMethods.SetOwner(windowHandle, _ownerWindowHandle);",
        "window.Activate();",
        "ShellNativeMethods.SetForegroundWindow(_windowHandle);",
    )
    for marker in required_markers:
        if marker not in controller:
            errors.append(f"设置窗口缺少激活契约标记：{marker}")

    if controller.count("ActivateWindow();") != 2:
        errors.append("设置与更新入口必须统一通过 ActivateWindow 激活窗口")

    main_window_constructor = (
        "new SettingsWindowController(this, ViewModel, UpdateViewModel)"
    )
    if main_window_constructor not in main_window:
        errors.append("设置窗口控制器必须接收主窗口作为原生 Owner")

    owner_index = controller.find(
        "WindowOwnershipNativeMethods.SetOwner(windowHandle, _ownerWindowHandle);"
    )
    window_cache_index = controller.find("_window = window;")
    if owner_index < 0 or window_cache_index < 0 or owner_index >= window_cache_index:
        errors.append("设置窗口必须先建立主窗口 Owner，再缓存为可复用窗口")

    ownership = WINDOW_OWNERSHIP_FILE.read_text(encoding="utf-8")
    ownership_markers = (
        "private const int OwnerWindowIndex = -8;",
        'EntryPoint = "SetWindowLongPtrW"',
        "SetWindowLongPtr(",
        "Marshal.GetLastPInvokeError()",
        "throw new Win32Exception",
    )
    for marker in ownership_markers:
        if marker not in ownership:
            errors.append(f"设置窗口缺少原生 Owner 契约标记：{marker}")

    activate_index = controller.find("window.Activate();")
    foreground_index = controller.find(
        "ShellNativeMethods.SetForegroundWindow(_windowHandle);"
    )
    if activate_index < 0 or foreground_index < 0 or activate_index >= foreground_index:
        errors.append("设置窗口必须先激活 WinUI Window，再请求进入前台")
