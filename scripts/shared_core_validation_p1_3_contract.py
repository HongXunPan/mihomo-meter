"""定义跨平台共享核心 P1.3 受保护主路径的静态契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_MARKERS = {
    "docs/跨平台共享核心P1.3受保护主路径技术方案.md": (
        "状态：P1.3-3 完整速率受保护主路径已启用",
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
        "`compact_rate` 仍调用影子路径",
    ),
    "docs/跨平台共享核心技术方案.md": (
        "状态：P1.3-3 字节数与完整速率受保护主路径已启用",
        "跨平台共享核心P1.3受保护主路径技术方案.md",
    ),
    "docs/架构概览.md": (
        "P1.3-3 已按",
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
}

METHOD_MARKERS = {
    "Sources/Presentation/TrafficStatisticsFormatter.swift": (
        (
            "static func bytes(",
            "private static func nativeBytes(",
            ("SharedCoreTrafficRoute.resolve(", "format: .byteCount"),
            ("SharedCoreTrafficShadow.observe(",),
        ),
    ),
    "Sources/Presentation/TrafficRateFormatter.swift": (
        (
            "static func compactString(",
            "static func string(",
            ("SharedCoreTrafficShadow.observe(", "format: .compactRate"),
            ("SharedCoreTrafficRoute.resolve(",),
        ),
        (
            "static func string(",
            "private static func nativeCompactString(",
            ("SharedCoreTrafficRoute.resolve(", "format: .rate"),
            ("SharedCoreTrafficShadow.observe(",),
        ),
    ),
    "platform/windows/MihomoMeter.Windows.App/Presentation/TrafficDisplayFormatter.cs": (
        (
            "public static string ByteCount(",
            "public static string RateValue(",
            ("SharedCoreTrafficRoute.Resolve(", "SharedCoreTrafficFormat.ByteCount"),
            ("SharedCoreTrafficShadow.Observe(",),
        ),
        (
            "public static string RateValue(",
            "public static string CompactRate(",
            ("SharedCoreTrafficRoute.Resolve(", "SharedCoreTrafficFormat.Rate"),
            ("SharedCoreTrafficShadow.Observe(",),
        ),
        (
            "public static string CompactRate(",
            "public static string DateTime(",
            ("SharedCoreTrafficShadow.Observe(", "SharedCoreTrafficFormat.CompactRate"),
            ("SharedCoreTrafficRoute.Resolve(",),
        ),
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

    for relative_path, contracts in METHOD_MARKERS.items():
        content = (ROOT / relative_path).read_text(encoding="utf-8")
        for start_marker, end_marker, required, forbidden in contracts:
            start_index = content.find(start_marker)
            end_index = content.find(end_marker, start_index + len(start_marker))
            if start_index < 0 or end_index < 0:
                failures.append(f"{relative_path} 无法定位 P1.3 调用点：{start_marker}")
                continue
            section = content[start_index:end_index]
            for marker in required:
                if marker not in section:
                    failures.append(f"{relative_path} 调用点缺少 P1.3 标记：{marker}")
            for marker in forbidden:
                if marker in section:
                    failures.append(f"{relative_path} 调用点模式冲突：{marker}")
