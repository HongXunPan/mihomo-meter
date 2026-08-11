#!/usr/bin/env python3
"""校验跨平台共享核心 P0 的静态工程契约。"""

from __future__ import annotations

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
    "platform/windows/MihomoMeter.Windows.Core/Application/MihomoMeterSharedCore.cs",
    "platform/windows/MihomoMeter.Windows.Tests/MihomoMeterSharedCoreTests.cs",
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
    "platform/windows/MihomoMeter.Windows.Core/Application/MihomoMeterSharedCore.cs": (
        'EntryPoint = "mm_core_abi_version"',
        'EntryPoint = "mm_scale_traffic"',
        "CallingConvention = CallingConvention.Cdecl",
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
        "rustup toolchain install 1.97.1 --profile minimal --target x86_64-pc-windows-msvc",
        "pwsh -File scripts/validate_windows.ps1",
    ),
}


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

    cargo_manifest = ROOT / "SharedCore/Cargo.toml"
    if cargo_manifest.is_file() and "[dependencies]" in cargo_manifest.read_text(
        encoding="utf-8"
    ):
        failures.append("共享核心 P0 不得引入 Cargo 依赖。")

    cargo_lock = ROOT / "SharedCore/Cargo.lock"
    if cargo_lock.is_file():
        lock_content = cargo_lock.read_text(encoding="utf-8")
        if "source =" in lock_content or "checksum =" in lock_content:
            failures.append("共享核心 P0 的 Cargo.lock 不得包含外部包。")

    if failures:
        for failure in failures:
            print(f"错误：{failure}")
        return 1

    print("跨平台共享核心 P0 静态契约检查通过。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
