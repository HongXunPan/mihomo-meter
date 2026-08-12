#!/usr/bin/env python3
"""校验跨平台共享核心当前阶段的静态工程契约。"""

from __future__ import annotations

import json
from pathlib import Path

from shared_core_validation_acceptance_contract import (
    validate_shared_core_acceptance,
)
from shared_core_validation_contract import FORBIDDEN_MARKERS, REQUIRED_MARKERS
from shared_core_validation_p1_3_contract import validate_shared_core_p1_3
from shared_core_validation_p1_4_contract import validate_shared_core_p1_4
from shared_core_validation_p2_contract import validate_shared_core_p2


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = (
    "rust-toolchain.toml",
    "SharedCore/Cargo.toml",
    "SharedCore/Cargo.lock",
    "SharedCore/src/lib.rs",
    "SharedCore/include/mihomo_meter_shared_core.h",
    "SharedCore/include/module.modulemap",
    "SharedCore/Adapters/Swift/MihomoMeterSharedCoreAdapter.swift",
    "SharedCore/Adapters/Swift/SharedCoreTrafficDisplayFormatter.swift",
    "SharedCore/Adapters/Swift/Probe/main.swift",
    "SharedCore/TestVectors/traffic_scale.json",
    "Sources/Application/AppDelegate.swift",
    "Sources/Application/SharedCoreRuntimeProbe.swift",
    "Sources/Application/SharedCoreTrafficRoute.swift",
    "Sources/Application/SharedCoreTrafficRouter.swift",
    "Sources/Application/SharedCoreTrafficShadow.swift",
    "Sources/Application/SharedCoreTrafficShadowComparator.swift",
    "Sources/Domain/SharedCoreRuntimeStatus.swift",
    "Sources/Domain/SharedCoreTrafficShadowObservation.swift",
    "Sources/Infrastructure/Diagnostics/AppDiagnosticEvent.swift",
    "Sources/Infrastructure/Diagnostics/AppCodeSigningInspector.swift",
    "Sources/Infrastructure/Diagnostics/SharedCoreTrafficDiagnosticReporter.swift",
    "Sources/Presentation/TrafficRateFormatter.swift",
    "Sources/Presentation/TrafficStatisticsFormatter.swift",
    "Tests/SharedCoreRuntimeProbeTests.swift",
    "Tests/SharedCoreTrafficLazyRouteTests.swift",
    "Tests/SharedCoreTrafficShadowComparatorTests.swift",
    "Tests/DiagnosticLoggerTests.swift",
    "platform/windows/MihomoMeter.Windows.Core/Application/MihomoMeterSharedCore.cs",
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreRuntimeProbe.cs",
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreTrafficRoute.cs",
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreTrafficRouter.cs",
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreTrafficDisplayFormatter.cs",
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreTrafficShadow.cs",
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreTrafficShadowComparator.cs",
    "platform/windows/MihomoMeter.Windows.Core/Application/TrafficDisplayUnits.cs",
    "platform/windows/MihomoMeter.Windows.App/Diagnostics/SharedCoreTrafficDiagnosticReporter.cs",
    "platform/windows/MihomoMeter.Windows.App/Diagnostics/StartupConsoleReporter.cs",
    "platform/windows/MihomoMeter.Windows.App/Presentation/NotificationAreaRealtimeController.cs",
    "platform/windows/MihomoMeter.Windows.App/Presentation/TrafficDisplayFormatter.cs",
    "platform/windows/MihomoMeter.Windows.App/Program.cs",
    "platform/windows/MihomoMeter.Windows.Tests/MihomoMeterSharedCoreTests.cs",
    "platform/windows/MihomoMeter.Windows.Tests/SharedCoreRuntimeProbeTests.cs",
    "platform/windows/MihomoMeter.Windows.Tests/SharedCoreTrafficLazyRouteTests.cs",
    "platform/windows/MihomoMeter.Windows.Tests/SharedCoreTrafficRouterTests.cs",
    "platform/windows/MihomoMeter.Windows.Tests/SharedCoreTrafficShadowComparatorTests.cs",
    "platform/windows/MihomoMeter.Windows.Tests/MihomoMeter.Windows.Tests.csproj",
    "scripts/shared_core_macos_toolchain.sh",
    "scripts/build_shared_core_macos.sh",
    "scripts/test_shared_core_macos.sh",
    "scripts/build_shared_core_windows.ps1",
    "scripts/shared_core_validation_contract.py",
    "scripts/shared_core_validation_p1_4_contract.py",
    "scripts/shared_core_validation_p2_contract.py",
    "scripts/windows_validation_shared_core_contract.py",
    "CONTRIBUTING.md",
    "docs/架构概览.md",
    "docs/跨平台共享核心P1.2b运行态验收指南.md",
    "docs/跨平台共享核心技术方案.md",
    "docs/跨平台共享核心P2代理分类技术方案.md",
)

REQUIRED_TRAFFIC_VALUES = {
    0,
    1,
    999,
    1_000,
    1_001,
    9_999,
    10_000,
    10_001,
    99_999,
    100_000,
    100_001,
    999_999,
    1_000_000,
    1_000_001,
    999_999_999,
    1_000_000_000,
    1_000_000_001,
    999_999_999_999,
    1_000_000_000_000,
    1_000_000_000_001,
    (1 << 64) - 1,
}


def validate_traffic_vectors(failures: list[str]) -> None:
    path = ROOT / "SharedCore/TestVectors/traffic_scale.json"
    if not path.is_file():
        return

    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        failures.append(f"统一流量缩放向量不是有效 JSON：{error}")
        return

    if not isinstance(document, dict):
        failures.append("统一流量缩放向量顶层必须为 JSON 对象。")
        return

    schema_version = document.get("schemaVersion")
    if type(schema_version) is not int or schema_version != 1:
        failures.append("统一流量缩放向量 schemaVersion 必须为整数 1。")

    raw_values = document.get("byteValues")
    if not isinstance(raw_values, list) or not raw_values:
        failures.append("统一流量缩放向量 byteValues 必须为非空数组。")
        return

    parsed_values: list[int] = []
    for raw_value in raw_values:
        if (
            not isinstance(raw_value, str)
            or not raw_value.isascii()
            or not raw_value.isdigit()
        ):
            failures.append("统一流量缩放向量必须使用十进制字符串。")
            return
        value = int(raw_value)
        if str(value) != raw_value or value > (1 << 64) - 1:
            failures.append(f"统一流量缩放向量超出 UInt64 或格式不规范：{raw_value}")
            return
        parsed_values.append(value)

    if parsed_values != sorted(set(parsed_values)):
        failures.append("统一流量缩放向量必须按数值升序排列且不得重复。")

    missing_values = sorted(REQUIRED_TRAFFIC_VALUES.difference(parsed_values))
    if missing_values:
        failures.append(f"统一流量缩放向量缺少关键边界值：{missing_values}")


def main() -> int:
    failures: list[str] = []
    for relative_path in REQUIRED_FILES:
        if not (ROOT / relative_path).is_file():
            failures.append(f"缺少共享核心文件：{relative_path}")

    for relative_path, markers in REQUIRED_MARKERS.items():
        path = ROOT / relative_path
        if not path.is_file():
            continue
        content = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in content:
                failures.append(f"{relative_path} 缺少标记：{marker}")

    for relative_path, markers in FORBIDDEN_MARKERS.items():
        path = ROOT / relative_path
        if not path.is_file():
            continue
        content = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker in content:
                failures.append(f"{relative_path} 包含禁止标记：{marker}")

    validate_traffic_vectors(failures)
    validate_shared_core_acceptance(failures)
    validate_shared_core_p1_3(failures)
    validate_shared_core_p1_4(failures)
    validate_shared_core_p2(failures)

    xcode_project = ROOT / "MihomoMeter.xcodeproj/project.pbxproj"
    if xcode_project.is_file() and xcode_project.read_text(encoding="utf-8").count(
        "baseConfigurationReference = AM0000000000000000000101"
    ) < 4:
        failures.append("应用与测试 Target 必须同时加载共享核心公共配置。")

    cargo_manifest = ROOT / "SharedCore/Cargo.toml"
    if cargo_manifest.is_file() and "[dependencies]" in cargo_manifest.read_text(
        encoding="utf-8"
    ):
        failures.append("共享核心 P1.2b 不得引入 Cargo 依赖。")

    cargo_lock = ROOT / "SharedCore/Cargo.lock"
    if cargo_lock.is_file():
        lock_content = cargo_lock.read_text(encoding="utf-8")
        if "source =" in lock_content or "checksum =" in lock_content:
            failures.append("共享核心 P1.2b 的 Cargo.lock 不得包含外部包。")

    if failures:
        for failure in failures:
            print(f"错误：{failure}")
        return 1

    print("跨平台共享核心静态契约检查通过。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
