"""定义跨平台共享核心静态门禁使用的工程契约。"""

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
        "SharedCoreTrafficDisplayFormatter.swift in Sources",
        "SharedCoreTrafficShadow.swift in Sources",
        "SharedCoreTrafficShadowComparator.swift in Sources",
        "SharedCoreTrafficShadowDiagnosticReporter.swift in Sources",
        "SharedCoreTrafficShadowObservation.swift in Sources",
        "SharedCoreTrafficShadowComparatorTests.swift in Sources",
    ),
    "Sources/Application/AppDelegate.swift": (
        "SharedCoreRuntimeProbe.run()",
        "SharedCoreTrafficShadow.configure(",
        "SharedCoreTrafficShadowDiagnosticReporter.report",
        ".sharedCoreRuntimeProbe(sharedCoreRuntimeStatus)",
    ),
    "Sources/Application/SharedCoreRuntimeProbe.swift": (
        "MihomoMeterSharedCoreAdapter.abiVersion",
        "MihomoMeterSharedCoreAdapter.scaleTraffic(bytes:)",
        "return .unexpectedResult",
    ),
    "Sources/Infrastructure/Diagnostics/AppDiagnosticEvent.swift": (
        "case sharedCoreRuntimeProbe(SharedCoreRuntimeStatus)",
        "case sharedCoreTrafficShadow(SharedCoreTrafficShadowObservation)",
        '"event=shared_core.runtime_probe result=\\(status.rawValue)"',
        '"event=shared_core.traffic_shadow"',
    ),
    "Sources/Presentation/TrafficStatisticsFormatter.swift": (
        "SharedCoreTrafficShadow.observe(",
        "format: .byteCount",
    ),
    "Sources/Presentation/TrafficRateFormatter.swift": (
        "SharedCoreTrafficShadow.observe(",
        "format: .rate",
        "format: .compactRate",
    ),
    "Sources/Application/SharedCoreTrafficShadow.swift": (
        "SharedCoreTrafficShadowComparator.compare(",
        "guard status != .matched else",
        "return nativeText",
    ),
    "Sources/Application/SharedCoreTrafficShadowComparator.swift": (
        "SharedCoreTrafficDisplayFormatter.string(",
        "return sharedText == nativeText ? .matched : .mismatch",
        "return .nativeCallFailed",
    ),
    "Sources/Infrastructure/Diagnostics/SharedCoreTrafficShadowDiagnosticReporter.swift": (
        "Set<SharedCoreTrafficShadowObservation>()",
        "observations.insert(observation).inserted",
        ".sharedCoreTrafficShadow(observation)",
    ),
    "Tests/SharedCoreRuntimeProbeTests.swift": (
        "testProductionRuntimeProbeLoadsSharedCore",
        "testRuntimeProbeStopsBeforeNativeCallForABIMismatch",
        "testRuntimeProbeMapsAdapterFailureWithoutThrowing",
    ),
    "Tests/SharedCoreTrafficShadowComparatorTests.swift": (
        "testComparatorMatchesAllProductionFormats",
        "testComparatorReportsMismatchWithoutChangingNativeText",
        "testComparatorMapsAdapterFailuresToCoarseStatuses",
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
        "SharedCoreTrafficShadow.ConfigureReporter(",
        "SharedCoreTrafficShadowReporter.Report",
        '"shared_core_runtime_native_call_failed"',
    ),
    "platform/windows/MihomoMeter.Windows.App/Diagnostics/SharedCoreTrafficShadowReporter.cs": (
        "HashSet<SharedCoreTrafficShadowObservation>",
        "ReportedObservations.Add(observation)",
        "StartupConsoleReporter.TrafficShadow(",
    ),
    "platform/windows/MihomoMeter.Windows.App/Presentation/TrafficDisplayFormatter.cs": (
        "SharedCoreTrafficShadow.Observe(",
        "SharedCoreTrafficFormat.ByteCount",
        "SharedCoreTrafficFormat.Rate",
        "SharedCoreTrafficFormat.CompactRate",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/TrafficDisplayUnits.cs": (
        "public static string Rate(ulong bytesPerSecond)",
        "public static string CompactRate(ulong? bytesPerSecond)",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreTrafficShadow.cs": (
        "SharedCoreTrafficShadowComparator.Compare(",
        "影子诊断不得影响仍由原生算法决定的生产输出",
        "return nativeText;",
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
        "SharedCoreTrafficDisplayFormatter.string(",
        "TrafficStatisticsFormatter.bytes(bytes)",
        "TrafficRateFormatter.string(from: bytes)",
        "TrafficRateFormatter.compactString(from: bytes)",
    ),
    "platform/windows/MihomoMeter.Windows.Tests/MihomoMeterSharedCoreTests.cs": (
        "TrafficDisplayUnits.ByteCount(bytes)",
        "TrafficDisplayUnits.Rate(bytes)",
        "TrafficDisplayUnits.CompactRate(bytes)",
        "SharedCoreTrafficDisplayFormatter.Format(",
        "MihomoMeterSharedCore.ScaleTraffic(bytes)",
        '"shared-core-traffic-scale.json"',
    ),
    "scripts/test_shared_core_macos.sh": (
        'source "${script_directory}/shared_core_macos_toolchain.sh"',
        'fixture_path="${project_root}/SharedCore/TestVectors/traffic_scale.json"',
        '"${project_root}/Sources/Domain/SharedCoreRuntimeStatus.swift"',
        '"${project_root}/Sources/Domain/SharedCoreTrafficShadowObservation.swift"',
        '"${project_root}/SharedCore/Adapters/Swift/SharedCoreTrafficDisplayFormatter.swift"',
        '"${project_root}/Sources/Application/SharedCoreTrafficShadowComparator.swift"',
        '"${project_root}/Sources/Application/SharedCoreTrafficShadow.swift"',
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
    "CONTRIBUTING.md": (
        "跨平台共享核心 P1.2b",
        "最终输出仍由原生算法决定",
    ),
    "docs/架构概览.md": (
        "P1.2b 生产影子比较",
        "双端字节数与速率格式化仍返回原生结果",
    ),
    "docs/跨平台共享核心技术方案.md": (
        "状态：P1.2b 生产影子比较",
        "返回值始终是原生结果",
        "按“格式类型 + 粗粒度状态”在单次进程生命周期内去重",
        "P1.2b 不提供运行时切换开关",
    ),
}
