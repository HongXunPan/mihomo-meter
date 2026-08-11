#!/usr/bin/env python3
"""校验跨平台共享核心 P1.2a 的静态工程契约。"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = (
    "rust-toolchain.toml",
    "SharedCore/Cargo.toml",
    "SharedCore/Cargo.lock",
    "SharedCore/src/lib.rs",
    "SharedCore/include/mihomo_meter_shared_core.h",
    "SharedCore/include/module.modulemap",
    "SharedCore/Adapters/Swift/MihomoMeterSharedCoreAdapter.swift",
    "SharedCore/Adapters/Swift/Probe/main.swift",
    "SharedCore/TestVectors/traffic_scale.json",
    "Sources/Application/SharedCoreRuntimeProbe.swift",
    "Sources/Domain/SharedCoreRuntimeStatus.swift",
    "Tests/SharedCoreRuntimeProbeTests.swift",
    "platform/windows/MihomoMeter.Windows.Core/Application/MihomoMeterSharedCore.cs",
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreRuntimeProbe.cs",
    "platform/windows/MihomoMeter.Windows.Tests/MihomoMeterSharedCoreTests.cs",
    "platform/windows/MihomoMeter.Windows.Tests/SharedCoreRuntimeProbeTests.cs",
    "platform/windows/MihomoMeter.Windows.Tests/MihomoMeter.Windows.Tests.csproj",
    "scripts/shared_core_macos_toolchain.sh",
    "scripts/build_shared_core_macos.sh",
    "scripts/test_shared_core_macos.sh",
    "scripts/build_shared_core_windows.ps1",
    "docs/跨平台共享核心技术方案.md",
)

REQUIRED_MARKERS = {
    "rust-toolchain.toml": (
        'channel = "1.97.1"',
        'profile = "minimal"',
        'components = ["rustfmt", "clippy"]',
    ),
    "SharedCore/Cargo.toml": (
        'name = "mihomo-meter-shared-core"',
        'crate-type = ["cdylib", "staticlib", "rlib"]',
    ),
    "SharedCore/src/lib.rs": (
        "pub const ABI_VERSION: u32 = 1;",
        'pub extern "C" fn mm_core_abi_version()',
        'pub unsafe extern "C" fn mm_scale_traffic(',
    ),
    "SharedCore/include/mihomo_meter_shared_core.h": (
        "#define MM_SHARED_CORE_ABI_VERSION 1u",
        "uint32_t mm_core_abi_version(void);",
        "int32_t mm_scale_traffic(uint64_t bytes, mm_scaled_traffic_t *output);",
    ),
    "Config.xcconfig": (
        "MIHOMO_METER_SHARED_CORE_TARGET[arch=arm64] = aarch64-apple-darwin",
        "MIHOMO_METER_SHARED_CORE_TARGET[arch=x86_64] = x86_64-apple-darwin",
        "-lmihomo_meter_shared_core",
    ),
    "MihomoMeter.xcodeproj/project.pbxproj": (
        "MihomoMeterSharedCoreAdapter.swift in Sources",
        "SharedCoreRuntimeProbe.swift in Sources",
        "SharedCoreRuntimeProbeTests.swift in Sources",
    ),
    "Sources/Application/AppDelegate.swift": (
        "SharedCoreRuntimeProbe.run()",
        ".sharedCoreRuntimeProbe(sharedCoreRuntimeStatus)",
    ),
    "Sources/Application/SharedCoreRuntimeProbe.swift": (
        "MihomoMeterSharedCoreAdapter.abiVersion",
        "MihomoMeterSharedCoreAdapter.scaleTraffic(bytes:)",
        "return .unexpectedResult",
    ),
    "Sources/Infrastructure/Diagnostics/AppDiagnosticEvent.swift": (
        "case sharedCoreRuntimeProbe(SharedCoreRuntimeStatus)",
        '"event=shared_core.runtime_probe result=\\(status.rawValue)"',
    ),
    "Tests/SharedCoreRuntimeProbeTests.swift": (
        "testProductionRuntimeProbeLoadsSharedCore",
        "testRuntimeProbeStopsBeforeNativeCallForABIMismatch",
        "testRuntimeProbeMapsAdapterFailureWithoutThrowing",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/MihomoMeterSharedCore.cs": (
        'EntryPoint = "mm_core_abi_version"',
        'EntryPoint = "mm_scale_traffic"',
        "CallingConvention = CallingConvention.Cdecl",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreRuntimeProbe.cs": (
        "public static SharedCoreRuntimeStatus Run()",
        "DllNotFoundException",
        "EntryPointNotFoundException",
        "BadImageFormatException",
    ),
    "platform/windows/MihomoMeter.Windows.App/Program.cs": (
        "ReportSharedCoreRuntimeStatus();",
        '"shared_core_runtime_native_call_failed"',
    ),
    "platform/windows/MihomoMeter.Windows.Tests/SharedCoreRuntimeProbeTests.cs": (
        "ProductionRuntimeProbeLoadsSharedCore",
        "RuntimeProbeContainsNativeLoadFailure",
    ),
    "platform/windows/MihomoMeter.Windows.App/MihomoMeter.Windows.App.csproj": (
        "<SharedCoreLibraryPath>",
        'Link="mihomo_meter_shared_core.dll"',
        "<CopyToPublishDirectory>PreserveNewest</CopyToPublishDirectory>",
    ),
    "platform/windows/MihomoMeter.Windows.Tests/MihomoMeter.Windows.Tests.csproj": (
        "<SharedCoreLibraryPath>",
        '<Content Include="$(SharedCoreLibraryPath)"',
        'Link="mihomo_meter_shared_core.dll"',
        '<Content Include="../../../SharedCore/TestVectors/traffic_scale.json"',
        'Link="Fixtures/shared-core-traffic-scale.json"',
    ),
    "SharedCore/Adapters/Swift/Probe/main.swift": (
        "SharedCoreRuntimeProbe.run() == .ready",
        "TrafficStatisticsFormatter.bytes(bytes)",
        "TrafficRateFormatter.string(from: bytes)",
        "TrafficRateFormatter.compactString(from: bytes)",
    ),
    "platform/windows/MihomoMeter.Windows.Tests/MihomoMeterSharedCoreTests.cs": (
        "TrafficDisplayUnits.ByteCount(bytes)",
        "MihomoMeterSharedCore.ScaleTraffic(bytes)",
        '"shared-core-traffic-scale.json"',
    ),
    "scripts/test_shared_core_macos.sh": (
        'source "${script_directory}/shared_core_macos_toolchain.sh"',
        'fixture_path="${project_root}/SharedCore/TestVectors/traffic_scale.json"',
        '"${project_root}/Sources/Domain/SharedCoreRuntimeStatus.swift"',
        '"${project_root}/Sources/Application/SharedCoreRuntimeProbe.swift"',
        '"${project_root}/Sources/Presentation/TrafficRateFormatter.swift"',
        '"${project_root}/Sources/Presentation/TrafficStatisticsFormatter.swift"',
        '"${probe_path}" "${fixture_path}"',
    ),
    "scripts/build_shared_core_macos.sh": (
        'source "${script_directory}/shared_core_macos_toolchain.sh"',
        "--architectures",
        "libmihomo_meter_shared_core.a",
    ),
    "scripts/build-debug.sh": (
        'scripts/build_shared_core_macos.sh --architectures "$(uname -m)"',
    ),
    "scripts/build-release-dmg.sh": (
        "scripts/build_shared_core_macos.sh",
        '--architectures "${build_architectures}"',
    ),
    "scripts/validate_windows.ps1": (
        '"build_shared_core_windows.ps1"',
        '"mihomo_meter_shared_core.dll"',
    ),
    ".github/workflows/ci.yml": (
        "rustup toolchain install 1.97.1 --profile minimal",
        "--component rustfmt --component clippy",
        "scripts/test_shared_core_macos.sh",
    ),
    ".github/workflows/windows.yml": (
        '"SharedCore/**"',
        "rustup toolchain install 1.97.1 --profile minimal --target x86_64-pc-windows-msvc",
    ),
    ".github/workflows/release.yml": (
        "--target aarch64-apple-darwin",
        "--target x86_64-apple-darwin",
        "scripts/test_shared_core_macos.sh",
        "rustup toolchain install 1.97.1 --profile minimal --target x86_64-pc-windows-msvc",
        "pwsh -File scripts/validate_windows.ps1",
    ),
}

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

    validate_traffic_vectors(failures)

    xcode_project = ROOT / "MihomoMeter.xcodeproj/project.pbxproj"
    if xcode_project.is_file() and xcode_project.read_text(encoding="utf-8").count(
        "baseConfigurationReference = AM0000000000000000000101"
    ) < 4:
        failures.append("应用与测试 Target 必须同时加载共享核心公共配置。")

    cargo_manifest = ROOT / "SharedCore/Cargo.toml"
    if cargo_manifest.is_file() and "[dependencies]" in cargo_manifest.read_text(
        encoding="utf-8"
    ):
        failures.append("共享核心 P1.2a 不得引入 Cargo 依赖。")

    cargo_lock = ROOT / "SharedCore/Cargo.lock"
    if cargo_lock.is_file():
        lock_content = cargo_lock.read_text(encoding="utf-8")
        if "source =" in lock_content or "checksum =" in lock_content:
            failures.append("共享核心 P1.2a 的 Cargo.lock 不得包含外部包。")

    if failures:
        for failure in failures:
            print(f"错误：{failure}")
        return 1

    print("跨平台共享核心 P1.2a 静态契约检查通过。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
