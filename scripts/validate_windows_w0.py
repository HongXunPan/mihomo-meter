#!/usr/bin/env python3
"""校验 Windows W0 工程的静态技术契约。"""

from __future__ import annotations

import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WINDOWS_ROOT = ROOT / "platform" / "windows"
PROJECT_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.App"
PROJECT_FILE = PROJECT_ROOT / "MihomoMeter.Windows.App.csproj"

EXPECTED_PROPERTIES = {
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

EXPECTED_PACKAGES = {
    "Microsoft.Windows.SDK.BuildTools": "10.0.28000.2526",
    "Microsoft.WindowsAppSDK": "2.3.1",
}

REQUIRED_FILES = (
    "App.xaml",
    "App.xaml.cs",
    "Program.cs",
    "MainWindow.xaml",
    "MainWindow.xaml.cs",
    "app.manifest",
    "run-w0-gate.cmd",
    "Diagnostics/W0ConsoleReporter.cs",
    "Lifecycle/ActivationRouter.cs",
    "Lifecycle/WindowLifecycleController.cs",
    "Lifecycle/NotificationAreaController.cs",
    "Lifecycle/FloatingWidgetController.cs",
    "Lifecycle/FloatingWidgetPainter.cs",
    "Lifecycle/FloatingWidgetPlacement.cs",
    "Lifecycle/FloatingWidgetWindow.cs",
    "Interop/ShellNativeMethods.cs",
    "Interop/FloatingWidgetNativeMethods.cs",
)

REQUIRED_CODE_MARKERS = {
    "Program.cs": ("FindOrRegisterForKey", "RedirectActivationToAsync"),
    "Lifecycle/WindowLifecycleController.cs": (
        "args.Cancel = true",
        "sender.Hide()",
        "RequestExit",
    ),
    "Lifecycle/NotificationAreaController.cs": ("ShellNotifyIcon", "TaskbarCreated"),
    "Lifecycle/FloatingWidgetWindow.cs": (
        "WindowStyleExtendedToolWindow",
        "WindowStyleExtendedNoActivate",
    ),
    "Lifecycle/FloatingWidgetController.cs": ("FloatingWidgetPosition? _lastPosition",),
}

FORBIDDEN_CODE_MARKERS = (
    "Microsoft.Data.Sqlite",
    "ClientWebSocket",
    "HttpClient",
    "CredentialManager",
    "RegistryKey",
    "File.WriteAll",
    "FileStream(",
    "EventLog",
)


def load_project() -> ET.Element:
    return ET.parse(PROJECT_FILE).getroot()


def project_values(root: ET.Element, tag: str) -> list[str]:
    return [element.text or "" for element in root.findall(f".//{tag}")]


def validate_global_json(errors: list[str]) -> None:
    data = json.loads((WINDOWS_ROOT / "global.json").read_text(encoding="utf-8"))
    sdk = data.get("sdk", {})
    if sdk.get("version") != "10.0.302":
        errors.append("global.json 必须锁定 .NET SDK 10.0.302")
    if sdk.get("allowPrerelease") is not False:
        errors.append("global.json 不得允许预览版 SDK")


def validate_project(errors: list[str]) -> None:
    root = load_project()
    for property_name, expected in EXPECTED_PROPERTIES.items():
        values = project_values(root, property_name)
        if values != [expected]:
            errors.append(f"{property_name} 必须唯一设置为 {expected}")

    package_elements = root.findall(".//PackageReference")
    packages = {
        element.attrib.get("Include", ""): element.attrib.get("Version", "")
        for element in package_elements
    }
    if len(package_elements) != len(EXPECTED_PACKAGES) or packages != EXPECTED_PACKAGES:
        errors.append(f"NuGet 依赖必须严格等于 {EXPECTED_PACKAGES}")


def validate_manifest(errors: list[str]) -> None:
    content = (PROJECT_ROOT / "app.manifest").read_text(encoding="utf-8")
    root = ET.fromstring(content)
    asm_v3 = {"v3": "urn:schemas-microsoft-com:asm.v3"}
    execution = root.find(".//v3:requestedExecutionLevel", asm_v3)
    if execution is None or execution.attrib.get("level") != "asInvoker":
        errors.append("应用清单必须使用 asInvoker 标准用户权限")
    if "PerMonitorV2" not in content:
        errors.append("应用清单必须声明 PerMonitorV2")
    if "{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}" not in content:
        errors.append("应用清单必须声明 Windows 10 supportedOS")


def validate_files_and_code(errors: list[str]) -> None:
    for relative_path in REQUIRED_FILES:
        if not (PROJECT_ROOT / relative_path).is_file():
            errors.append(f"缺少 Windows W0 文件：{relative_path}")

    for relative_path, markers in REQUIRED_CODE_MARKERS.items():
        path = PROJECT_ROOT / relative_path
        if not path.is_file():
            continue
        content = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in content:
                errors.append(f"{relative_path} 缺少契约标记：{marker}")

    code = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted(PROJECT_ROOT.rglob("*.cs"))
    )
    for marker in FORBIDDEN_CODE_MARKERS:
        if marker in code:
            errors.append(f"Windows W0 不得出现持久化或业务接入标记：{marker}")


def main() -> int:
    errors: list[str] = []
    try:
        validate_global_json(errors)
        validate_project(errors)
        validate_manifest(errors)
        validate_files_and_code(errors)
    except (OSError, ET.ParseError, json.JSONDecodeError) as exception:
        errors.append(f"读取工程契约失败：{type(exception).__name__}")

    if errors:
        for error in errors:
            print(f"错误：{error}", file=sys.stderr)
        return 1

    print("Windows W0 静态契约检查通过。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
