"""定义跨平台共享核心 P1.3 受保护主路径的静态契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_MARKERS = {
    "docs/跨平台共享核心P1.3受保护主路径技术方案.md": (
        "状态：P1.3-1 路由基础设施已完成，尚未启用共享主路径",
        "受保护主路径仅在共享文本与原生文本完全一致时返回共享文本",
        "ABI 不匹配、动态库调用失败、未知单位、不支持的小数位、文本不一致或其他未知错误",
        "不增加用户开关、持久化模式或可远程修改的配置",
        "shared_core.traffic_route",
        "result=shared_primary",
        "native_fallback",
        "P1.3-1",
        "P1.3-2",
        "P1.3-3",
        "P1.3-4",
        "P1.3-5",
        "不删除原生格式化实现",
        "每个平台至少连续连接 30 分钟",
        "只回滚该格式的调用点",
        "三类生产格式器仍全部调用影子路径",
    ),
    "docs/跨平台共享核心技术方案.md": (
        "状态：P1.3-1 路由基础设施已完成",
        "跨平台共享核心P1.3受保护主路径技术方案.md",
    ),
    "docs/架构概览.md": (
        "P1.3-1 已按",
        "跨平台共享核心P1.3受保护主路径技术方案.md",
    ),
    "Sources/Application/SharedCoreTrafficRouter.swift": (
        "enum SharedCoreTrafficRouteSource",
        "enum SharedCoreTrafficRouter",
        "source: .sharedPrimary",
        "source: .nativeFallback",
    ),
    "Sources/Application/SharedCoreTrafficRoute.swift": (
        "struct SharedCoreTrafficRouteObservation",
        "static func resolve(",
        "try reporter?(observation)",
    ),
    "Sources/Application/AppDelegate.swift": (
        "SharedCoreTrafficRoute.configure(",
        "SharedCoreTrafficDiagnosticReporter.reportRoute",
    ),
    "Sources/Infrastructure/Diagnostics/AppDiagnosticEvent.swift": (
        "case sharedCoreTrafficRoute(SharedCoreTrafficRouteObservation)",
        '"event=shared_core.traffic_route"',
        '"result=\\(observation.source.rawValue)"',
    ),
    "Tests/SharedCoreTrafficShadowComparatorTests.swift": (
        "testRouterReturnsSharedTextOnlyForExactMatch",
        "testRouterFallsBackToNativeTextForMismatchAndSharedFailures",
        "testRouteDeduplicatesObservationsAndIgnoresReporterFailure",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreTrafficRouter.cs": (
        "internal static class SharedCoreTrafficRouter",
        "SharedCoreTrafficRouteSource.SharedPrimary",
        "SharedCoreTrafficRouteSource.NativeFallback",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreTrafficRoute.cs": (
        "public static class SharedCoreTrafficRoute",
        "public static string Resolve(",
        "reporter?.Invoke(observation)",
    ),
    "platform/windows/MihomoMeter.Windows.App/Program.cs": (
        "SharedCoreTrafficRoute.ConfigureReporter(",
        "SharedCoreTrafficDiagnosticReporter.ReportRoute",
    ),
    "platform/windows/MihomoMeter.Windows.App/Diagnostics/StartupConsoleReporter.cs": (
        "public static void TrafficRoute(string format, string result, string status)",
        "event=shared_core.traffic_route",
    ),
    "platform/windows/MihomoMeter.Windows.Tests/SharedCoreTrafficRouterTests.cs": (
        "RouterReturnsSharedTextOnlyForExactMatch",
        "RouterFallsBackToNativeTextForMismatchAndSharedFailures",
        "RouteDeduplicatesObservationsAndIgnoresReporterFailure",
    ),
    "Sources/Presentation/TrafficStatisticsFormatter.swift": (
        "SharedCoreTrafficShadow.observe(",
    ),
    "Sources/Presentation/TrafficRateFormatter.swift": (
        "SharedCoreTrafficShadow.observe(",
    ),
    "platform/windows/MihomoMeter.Windows.App/Presentation/TrafficDisplayFormatter.cs": (
        "SharedCoreTrafficShadow.Observe(",
    ),
}

FORBIDDEN_MARKERS = {
    "Sources/Presentation/TrafficStatisticsFormatter.swift": (
        "SharedCoreTrafficRoute.resolve(",
    ),
    "Sources/Presentation/TrafficRateFormatter.swift": (
        "SharedCoreTrafficRoute.resolve(",
    ),
    "platform/windows/MihomoMeter.Windows.App/Presentation/TrafficDisplayFormatter.cs": (
        "SharedCoreTrafficRoute.Resolve(",
    ),
}


def validate_shared_core_p1_3(failures: list[str]) -> None:
    for relative_path, markers in REQUIRED_MARKERS.items():
        path = ROOT / relative_path
        if not path.is_file():
            failures.append(f"缺少 P1.3 文件：{relative_path}")
            continue

        content = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in content:
                failures.append(f"{relative_path} 缺少 P1.3 标记：{marker}")

    for relative_path, markers in FORBIDDEN_MARKERS.items():
        content = (ROOT / relative_path).read_text(encoding="utf-8")
        for marker in markers:
            if marker in content:
                failures.append(f"{relative_path} 提前启用 P1.3 主路径：{marker}")
