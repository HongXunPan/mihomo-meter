#!/usr/bin/env python3
"""校验 Windows 工程的静态技术契约。"""

from __future__ import annotations

import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from windows_validation_contract import (
    APP_PROJECT,
    APP_ROOT,
    CORE_PROJECT,
    CORE_ROOT,
    EXPECTED_APP_PACKAGES,
    EXPECTED_APP_PROPERTIES,
    EXPECTED_CORE_PACKAGES,
    EXPECTED_SOLUTION_PROJECTS,
    EXPECTED_TEST_PACKAGES,
    FORBIDDEN_CODE_MARKERS,
    FORBIDDEN_PROJECT_MARKERS,
    REQUIRED_APP_FILES,
    REQUIRED_CODE_MARKERS,
    REQUIRED_CORE_FILES,
    REQUIRED_REPOSITORY_FILES,
    REQUIRED_TEST_FILES,
    ROOT,
    SOLUTION_FILE,
    TEST_PROJECT,
    TEST_ROOT,
    WINDOWS_ROOT,
)
from windows_validation_notification_area_contract import (
    validate_notification_area_command_ids,
)


def configure_console_encoding() -> None:
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if callable(reconfigure):
            reconfigure(encoding="utf-8", errors="backslashreplace")


def load_xml(path: Path) -> ET.Element:
    return ET.parse(path).getroot()


def project_values(root: ET.Element, tag: str) -> list[str]:
    return [element.text or "" for element in root.findall(f".//{tag}")]


def package_references(root: ET.Element) -> dict[str, str]:
    return {
        element.attrib.get("Include", ""): element.attrib.get("Version", "")
        for element in root.findall(".//PackageReference")
    }


def validate_global_json(errors: list[str]) -> None:
    data = json.loads((WINDOWS_ROOT / "global.json").read_text(encoding="utf-8"))
    sdk = data.get("sdk", {})
    if sdk.get("version") != "10.0.302":
        errors.append("global.json 必须锁定 .NET SDK 10.0.302")
    if sdk.get("allowPrerelease") is not False:
        errors.append("global.json 不得允许预览版 SDK")
    if data.get("msbuild-sdks", {}).get("MSTest.Sdk") != "4.3.2":
        errors.append("global.json 必须锁定 MSTest.Sdk 4.3.2")
    if data.get("test", {}).get("runner") != "Microsoft.Testing.Platform":
        errors.append("global.json 必须使用 Microsoft Testing Platform")


def validate_app_project(errors: list[str]) -> None:
    root = load_xml(APP_PROJECT)
    for property_name, expected in EXPECTED_APP_PROPERTIES.items():
        values = project_values(root, property_name)
        if values != [expected]:
            errors.append(f"App {property_name} 必须唯一设置为 {expected}")

    packages = package_references(root)
    if packages != EXPECTED_APP_PACKAGES:
        errors.append(f"App NuGet 依赖必须严格等于 {EXPECTED_APP_PACKAGES}")

    references = {
        element.attrib.get("Include", "").replace("\\", "/")
        for element in root.findall(".//ProjectReference")
    }
    if references != {"../MihomoMeter.Windows.Core/MihomoMeter.Windows.Core.csproj"}:
        errors.append("App 必须且只能引用 Windows Core 项目")

    content = APP_PROJECT.read_text(encoding="utf-8")
    if "run-w0-gate.cmd" in content:
        errors.append("Windows 当前阶段 App 发布项目不得继续复制 run-w0-gate.cmd")


def validate_core_and_test_projects(errors: list[str]) -> None:
    core = load_xml(CORE_PROJECT)
    if project_values(core, "TargetFramework") != ["net10.0"]:
        errors.append("Core TargetFramework 必须为 net10.0")
    if package_references(core) != EXPECTED_CORE_PACKAGES:
        errors.append(f"Core NuGet 依赖必须严格等于 {EXPECTED_CORE_PACKAGES}")

    tests = load_xml(TEST_PROJECT)
    if tests.attrib.get("Sdk") != "MSTest.Sdk":
        errors.append("Tests 必须使用由 global.json 锁定的 MSTest.Sdk")
    if project_values(tests, "TargetFramework") != ["net10.0"]:
        errors.append("Tests TargetFramework 必须为 net10.0")
    if project_values(tests, "TestingExtensionsProfile") != ["None"]:
        errors.append("Tests 必须关闭额外 Testing Platform 扩展")
    if package_references(tests) != EXPECTED_TEST_PACKAGES:
        errors.append(f"Tests NuGet 依赖必须严格等于 {EXPECTED_TEST_PACKAGES}")

    fixture_links = [
        element.attrib.get("Include", "").replace("\\", "/")
        for element in tests.findall(".//None")
    ]
    if fixture_links != ["../../../Tests/Fixtures/*.json"]:
        errors.append("Tests 必须直接链接仓库共享 Fixtures")


def validate_solution(errors: list[str]) -> None:
    root = load_xml(SOLUTION_FILE)
    projects = {
        element.attrib.get("Path", "").replace("\\", "/")
        for element in root.findall(".//Project")
    }
    if projects != EXPECTED_SOLUTION_PROJECTS:
        errors.append(f"Windows solution 项目必须严格等于 {EXPECTED_SOLUTION_PROJECTS}")


def validate_manifest(errors: list[str]) -> None:
    content = (APP_ROOT / "app.manifest").read_text(encoding="utf-8")
    root = ET.fromstring(content)
    execution = root.find(
        ".//v3:requestedExecutionLevel",
        {"v3": "urn:schemas-microsoft-com:asm.v3"},
    )
    if execution is None or execution.attrib.get("level") != "asInvoker":
        errors.append("应用清单必须使用 asInvoker 标准用户权限")
    if "PerMonitorV2" not in content:
        errors.append("应用清单必须声明 PerMonitorV2")
    if "{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}" not in content:
        errors.append("应用清单必须声明 Windows 10 supportedOS")


def validate_xaml() -> None:
    for path in sorted(APP_ROOT.rglob("*.xaml")):
        load_xml(path)


def validate_files_and_code(errors: list[str]) -> None:
    for relative_path in REQUIRED_REPOSITORY_FILES:
        if not (ROOT / relative_path).is_file():
            errors.append(f"缺少 Windows 当前阶段仓库文件：{relative_path}")
    for relative_path in REQUIRED_APP_FILES:
        if not (APP_ROOT / relative_path).is_file():
            errors.append(f"缺少 Windows App 文件：{relative_path}")
    for relative_path in REQUIRED_CORE_FILES:
        if not (CORE_ROOT / relative_path).is_file():
            errors.append(f"缺少 Windows Core 文件：{relative_path}")
    for relative_path in REQUIRED_TEST_FILES:
        if not (TEST_ROOT / relative_path).is_file():
            errors.append(f"缺少 Windows Tests 文件：{relative_path}")

    for path, markers in REQUIRED_CODE_MARKERS.items():
        if not path.is_file():
            continue
        content = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in content:
                errors.append(f"{path.relative_to(ROOT)} 缺少契约标记：{marker}")

    project_content = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted(WINDOWS_ROOT.rglob("*.csproj"))
    )
    for marker in FORBIDDEN_PROJECT_MARKERS:
        if marker in project_content:
            errors.append(f"Windows 当前阶段不得包含未批准项目标记：{marker}")

    code = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted(WINDOWS_ROOT.rglob("*.cs"))
    )
    for marker in FORBIDDEN_CODE_MARKERS:
        if marker in code:
            errors.append(f"Windows 当前阶段不得包含越界代码标记：{marker}")

    address_store = (
        APP_ROOT / "Infrastructure/Configuration/JsonControllerAddressStore.cs"
    ).read_text(encoding="utf-8")
    if "Secret" in address_store:
        errors.append("普通设置实现不得定义或写入 Secret")

    quota_schema = (
        CORE_ROOT / "Infrastructure/Quota/QuotaLedgerSchema.cs"
    ).read_text(encoding="utf-8")
    for marker in (
        "subscription_url",
        "raw_url",
        "controller_secret",
        "provider_key",
        "response_body",
        "response_headers",
    ):
        if marker in quota_schema.lower():
            errors.append(f"配额 schema 不得包含敏感字段：{marker}")

    profile_settings = (
        APP_ROOT / "Infrastructure/Configuration/JsonProfileDirectoryStore.cs"
    ).read_text(encoding="utf-8")
    if "SubscriptionUri" in profile_settings or "UrlFingerprint" in profile_settings:
        errors.append("Profile 路径设置不得承载订阅 URL 或指纹")

    runtime_models = "\n".join(
        (CORE_ROOT / relative_path).read_text(encoding="utf-8")
        for relative_path in (
            "Domain/ConnectionAttributionCoverage.cs",
            "Domain/ConnectionAnalytics.cs",
            "Domain/ConnectionMetadata.cs",
            "Domain/TrafficMeasurement.cs",
            "Application/LiveConnectionProjection.cs",
        )
    )
    if "ProcessPath" in runtime_models:
        errors.append("W2D-1 领域与应用模型不得承载完整进程路径")

    persistence_code = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted((CORE_ROOT / "Infrastructure").rglob("*Schema.cs"))
    ).lower()
    for marker in (
        "connection_id",
        "process_path",
        "destination_ip",
        "destination_port",
        "rule_name",
        "proxy_chain",
    ):
        if marker in persistence_code:
            errors.append(f"W2D-1 持久化 schema 不得包含连接明细字段：{marker}")

    attribution_schema = (
        CORE_ROOT
        / "Infrastructure/ConnectionAnalytics/ConnectionAnalyticsLedgerSchema.cs"
    ).read_text(encoding="utf-8").lower()
    for marker in (
        "connection_id",
        "url",
        "ip_address",
        "destination",
        "port",
        "process_path",
        "node",
        "rule",
        "started_at",
        "ended_at",
        "observed_at",
    ):
        if marker in attribution_schema:
            errors.append(f"W2D-2 归因 schema 不得包含连接明细字段：{marker}")


def main() -> int:
    configure_console_encoding()
    errors: list[str] = []
    try:
        validate_global_json(errors)
        validate_app_project(errors)
        validate_core_and_test_projects(errors)
        validate_solution(errors)
        validate_manifest(errors)
        validate_xaml()
        validate_files_and_code(errors)
        validate_notification_area_command_ids(errors)
    except (OSError, ET.ParseError, json.JSONDecodeError) as exception:
        errors.append(f"读取工程契约失败：{type(exception).__name__}")

    if errors:
        for error in errors:
            print(f"错误：{error}", file=sys.stderr)
        return 1

    print("Windows 静态契约检查通过。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
