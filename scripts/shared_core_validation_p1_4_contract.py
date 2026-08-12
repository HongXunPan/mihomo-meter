"""定义跨平台共享核心 P1.4 懒原生回退的阶段静态契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_MARKERS = {
    "docs/跨平台共享核心P1.4懒原生回退技术方案.md": (
        "状态：P1.4-4 三类格式均已切换，待双端实机验收",
        "共享优先、原生懒回退",
        "成功路径不得求值原生闭包",
        "status=succeeded",
        "`mismatch` 只保留为差分测试失败",
        "至少 10,000 个 `UInt64` 样本",
        "P1.4-1",
        "P1.4-2",
        "P1.4-3",
        "P1.4-4",
        "P1.4-5",
        "不允许顺带切换生产调用点",
        "恢复为 P1.3 逐次对照入口",
        "P1.3 对照路由",
        "独立懒路由结果与路由状态",
        "P1.4-2 至 P1.4-4 依次切换双端",
        "Windows 紧凑速率的无值占位分支",
    ),
    "docs/跨平台共享核心技术方案.md": (
        "P1.4-4 三类格式已切换",
        "跨平台共享核心P1.4懒原生回退技术方案.md",
    ),
    "CONTRIBUTING.md": (
        "待按",
        "跨平台共享核心P1.4懒原生回退技术方案.md",
    ),
    "Sources/Application/SharedCoreTrafficRouter.swift": (
        "enum SharedCoreTrafficRouteStatus",
        "struct SharedCoreTrafficLazyRouteResult",
        "static func routeLazy(",
        "nativeFallback: () -> String",
        "status: .succeeded",
    ),
    "Sources/Application/SharedCoreTrafficRoute.swift": (
        "static func resolveLazy(",
        "status: result.status",
        "private static func report(",
    ),
    "Tests/SharedCoreTrafficLazyRouteTests.swift": (
        "testLazyRouterDoesNotEvaluateFallbackOnSuccess",
        "testLazyRouterStopsBeforeScalingForABIMismatch",
        "testLazyRouterEvaluatesFallbackExactlyOnceForSharedFailures",
        "testLazyRouteIgnoresReporterFailureWithoutEvaluatingFallback",
        "testDeterministicDifferentialMatchesNativeFormatters",
        "10_000",
        "SplitMix64",
        "TrafficStatisticsFormatter.nativeBytes(bytes)",
        "TrafficRateFormatter.nativeString(from: bytes)",
        "TrafficRateFormatter.nativeCompactString(from: bytes)",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreTrafficRouter.cs": (
        "public enum SharedCoreTrafficRouteStatus",
        "public readonly record struct SharedCoreTrafficLazyRouteResult",
        "RouteLazy(",
        "Func<string> nativeFallback",
        "SharedCoreTrafficRouteStatus.Succeeded",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreTrafficRoute.cs": (
        "public static string ResolveLazy(",
        "private static void Report(",
    ),
    "platform/windows/MihomoMeter.Windows.App/Diagnostics/SharedCoreTrafficDiagnosticReporter.cs": (
        "SharedCoreTrafficRouteStatus.Succeeded => \"succeeded\"",
    ),
    "platform/windows/MihomoMeter.Windows.Tests/SharedCoreTrafficLazyRouteTests.cs": (
        "LazyRouterDoesNotEvaluateFallbackOnSuccess",
        "LazyRouterStopsBeforeScalingForAbiMismatch",
        "LazyRouterEvaluatesFallbackExactlyOnceForSharedFailures",
        "LazyRouteIgnoresReporterFailureWithoutEvaluatingFallback",
        "DeterministicDifferentialMatchesNativeFormatters",
        "10_000",
        "SplitMix64",
        "TrafficDisplayUnits.ByteCount(bytes)",
        "TrafficDisplayUnits.Rate(bytes)",
        "TrafficDisplayUnits.CompactRate(bytes)",
    ),
    "MihomoMeter.xcodeproj/project.pbxproj": (
        "SharedCoreTrafficLazyRouteTests.swift in Sources",
    ),
}

CURRENT_PRODUCTION_MARKERS = {
    "Sources/Presentation/TrafficStatisticsFormatter.swift": (
        "SharedCoreTrafficRoute.resolveLazy(",
        "nativeFallback: { nativeBytes(value) }",
        "format: .byteCount",
    ),
    "Sources/Presentation/TrafficRateFormatter.swift": (
        "nativeFallback: { nativeCompactString(from: bytesPerSecond) }",
        "format: .compactRate",
        "nativeFallback: { nativeString(from: bytesPerSecond) }",
        "format: .rate",
    ),
    "platform/windows/MihomoMeter.Windows.App/Presentation/TrafficDisplayFormatter.cs": (
        "SharedCoreTrafficRoute.ResolveLazy(",
        "() => TrafficDisplayUnits.ByteCount(bytes)",
        "() => TrafficDisplayUnits.Rate(bytesPerSecond)",
        "() => TrafficDisplayUnits.CompactRate(bytesPerSecond)",
        "if (bytesPerSecond is null)",
    ),
}

FORBIDDEN_PRODUCTION_MARKERS = {
    "Sources/Presentation/TrafficStatisticsFormatter.swift": (
        "let nativeText = nativeBytes(value)",
        "nativeText: nativeText",
    ),
    "Sources/Presentation/TrafficRateFormatter.swift": (
        "let nativeText",
        "nativeText: nativeText",
    ),
    "platform/windows/MihomoMeter.Windows.App/Presentation/TrafficDisplayFormatter.cs": (
        "var nativeText",
        "SharedCoreTrafficRoute.Resolve(",
    ),
}


def validate_shared_core_p1_4(failures: list[str]) -> None:
    for relative_path, markers in REQUIRED_MARKERS.items():
        path = ROOT / relative_path
        if not path.is_file():
            failures.append(f"缺少 P1.4 文件：{relative_path}")
            continue
        content = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in content:
                failures.append(f"{relative_path} 缺少 P1.4 标记：{marker}")

    for relative_path, markers in CURRENT_PRODUCTION_MARKERS.items():
        content = (ROOT / relative_path).read_text(encoding="utf-8")
        for marker in markers:
            if marker not in content:
                failures.append(
                    f"{relative_path} 在 P1.4-4 缺少当前生产路径：{marker}"
                )

    for relative_path, markers in FORBIDDEN_PRODUCTION_MARKERS.items():
        content = (ROOT / relative_path).read_text(encoding="utf-8")
        for marker in markers:
            if marker in content:
                failures.append(
                    f"{relative_path} 在 P1.4-4 调用点模式冲突：{marker}"
                )
