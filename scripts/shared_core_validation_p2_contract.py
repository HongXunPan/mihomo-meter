"""定义跨平台共享核心 P2 代理分类的阶段静态契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_MARKERS = {
    "docs/跨平台共享核心P2代理分类技术方案.md": (
        "状态：P2-6 共享优先、原生懒回退已实现",
        "P2-F0 已先修正双端原生基线",
        "不超过 64 字节的 ASCII 输入",
        "0 | `unrecognized`",
        "不直接映射未知，必须执行原生回退",
        "mm_classify_proxy_type",
        "proxy_type_classification.json",
        "P2-1 不得接入生产",
        "P2-2 不得改变生产结果",
        "P2-4 不得停止逐次原生比较",
        "P2-6 不得删除原生分类",
        "P2-3、P2-5 与 P2-7",
        "跨平台共享核心P2-3运行态验收指南.md",
        "跨平台共享核心P2-3验收记录-2026-08-12.md",
        "跨平台共享核心P2-5运行态验收指南.md",
        "跨平台共享核心P2-5验收记录-2026-08-12.md",
        "跨平台共享核心P2-7运行态验收指南.md",
        "DIRECT、REJECT 或未知被并入 Proxy",
    ),
    "docs/跨平台共享核心P2-3运行态验收指南.md": (
        "状态：已通过（2026-08-12）",
        "两次独立启动",
        "连续连接 30 分钟",
        "Proxy、DIRECT 与空闲切换",
        "source=shared_shadow status=matched",
        "source=native_fallback status=unrecognized",
        "不得记录原始代理类型",
        "跨平台共享核心P2-3验收记录-2026-08-12.md",
    ),
    "docs/跨平台共享核心P2-3验收记录-2026-08-12.md": (
        "状态：通过",
        "确认日期：2026-08-12",
        "macOS 26.5.2（25F84，x86_64）",
        "Windows 10 22H2 x64 标准用户",
        "bce75a32492a344865026f0e2b432bbc1d94958d",
        "shared_shadow + matched",
        "禁止状态 | 无 | 无",
        "P2-4 受保护主路径",
    ),
    "docs/跨平台共享核心P2-5运行态验收指南.md": (
        "状态：已通过（2026-08-12）",
        "两次独立启动",
        "连续连接 30 分钟",
        "Proxy、DIRECT 与空闲切换",
        "event=shared_core.proxy_type_route",
        "source=shared_primary status=matched",
        "source=native_fallback status=unrecognized",
        "不得进入 P2-6",
    ),
    "docs/跨平台共享核心P2-5验收记录-2026-08-12.md": (
        "状态：通过",
        "确认日期：2026-08-12",
        "macOS 26.5.2（25F84，x86_64）",
        "Windows 10 22H2 x64 标准用户",
        "d10627e4b9c9415288dc6b68e41e2675747636a5",
        "shared_primary + matched",
        "禁止回退状态 | 无 | 无",
        "P2-6 共享优先、原生懒回退",
    ),
    "docs/跨平台共享核心P2-7运行态验收指南.md": (
        "状态：待双端实机验收",
        "两次独立启动",
        "连续连接 30 分钟",
        "Proxy、DIRECT 与空闲切换",
        "event=shared_core.proxy_type_route",
        "source=shared_primary status=succeeded",
        "source=native_fallback status=unrecognized",
        "回滚到 P2-4 受保护路由",
    ),
    "docs/跨平台共享核心技术方案.md": (
        "跨平台共享核心P2代理分类技术方案.md",
        "未识别类型必须回退原生分类",
    ),
    "docs/架构概览.md": (
        "P2-7",
        "跨平台共享核心P2代理分类技术方案.md",
    ),
    "docs/数据与隐私.md": (
        "代理分类影子、受保护或懒回退路由的粗粒度来源和状态",
        "原始代理类型",
    ),
    "CONTRIBUTING.md": (
        "跨平台共享核心P2代理分类技术方案.md",
        "P2-5 受保护主路径双端门禁均已于 2026-08-12 通过",
        "跨平台共享核心P2-5验收记录-2026-08-12.md",
        "跨平台共享核心P2-7运行态验收指南.md",
    ),
    "Sources/Domain/ProxyClassifier.swift": (
        ".filter { $0.isLetter || $0.isNumber }",
        '"hysteria2"',
        '"socks5"',
        "resolveProxyType(rawType, nativeClassification)",
        "typealias LazyProxyTypeResolver",
        "resolveProxyTypeLazily",
    ),
    "Tests/ProxyClassifierTests.swift": (
        "testClassifiesEverySupportedConcreteProxyType",
        "testInvokesInjectedResolverOnlyAfterCatalogHitWithNativeClassification",
        '"Hysteria2"',
        '"Socks5"',
        "testLazyResolverControlsWhetherNativeClassificationIsEvaluated",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Domain/ProxyClassifier.cs": (
        "char.IsLetter(character) || char.IsNumber(character)",
        '"hysteria2"',
        '"socks5"',
        "_resolveProxyType!(rawType, nativeClassification)",
        "public delegate ProxyClassification LazyProxyTypeResolver",
        "_resolveProxyTypeLazily(rawType, () => ClassifyNatively(rawType))",
    ),
    "platform/windows/MihomoMeter.Windows.Tests/ProxyClassifierTests.cs": (
        "ClassifiesEverySupportedConcreteProxyType",
        "InvokesInjectedResolverOnlyAfterCatalogHitWithNativeClassification",
        '"Hysteria2"',
        '"Socks5"',
        "LazyResolverControlsWhetherNativeClassificationIsEvaluated",
    ),
    "SharedCore/src/lib.rs": (
        "pub unsafe extern \"C\" fn mm_classify_proxy_type(",
        "MAXIMUM_PROXY_TYPE_INPUT_LENGTH",
        "PROXY_TYPE_UNRECOGNIZED",
        "proxy_type_classification_validates_abi_pointers",
    ),
    "SharedCore/include/mihomo_meter_shared_core.h": (
        "MM_PROXY_TYPE_MAX_INPUT_LENGTH 64u",
        "mm_proxy_type_classification_t",
        "mm_classify_proxy_type",
    ),
    "SharedCore/TestVectors/proxy_type_classification.json": (
        '"Hysteria2"',
        '"Socks5"',
        '"unsupported_input"',
        '"input_too_long"',
    ),
    "SharedCore/Adapters/Swift/MihomoMeterSharedCoreAdapter.swift": (
        "enum SharedProxyTypeClassification",
        "static func classifyProxyType(",
        "unsupportedProxyTypeInput",
        "proxyTypeInputTooLong",
    ),
    "SharedCore/Adapters/Swift/Probe/main.swift": (
        "ProxyTypeClassificationFixture",
        "MihomoMeterSharedCoreAdapter.classifyProxyType",
        "ProxyClassifier(",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/MihomoMeterSharedCore.cs": (
        "public enum SharedProxyTypeClassification",
        "public static SharedProxyTypeClassification ClassifyProxyType(",
        'EntryPoint = "mm_classify_proxy_type"',
    ),
    "platform/windows/MihomoMeter.Windows.Tests/MihomoMeterSharedCoreTests.cs": (
        "ProxyTypeClassificationMatchesNativeClassifierForCanonicalVectors",
        "MihomoMeterSharedCore.ClassifyProxyType(",
        "ClassifyNatively(",
    ),
    "platform/windows/MihomoMeter.Windows.Tests/MihomoMeter.Windows.Tests.csproj": (
        "proxy_type_classification.json",
        "shared-core-proxy-type-classification.json",
    ),
    "scripts/test_shared_core_macos.sh": (
        "proxy_type_classification.json",
        "SharedCoreProxyTypeRouter.swift",
        "SharedCoreProxyTypeShadow.swift",
        '"${proxy_fixture_path}"',
    ),
    "Sources/Domain/SharedCoreProxyTypeShadowObservation.swift": (
        "enum SharedCoreProxyTypeShadowSource",
        'case sharedShadow = "shared_shadow"',
        'case sharedPrimary = "shared_primary"',
        'case nativeFallback = "native_fallback"',
        "case succeeded",
        "case unrecognized",
        "SharedCoreProxyTypeShadowObservationGate",
    ),
    "Sources/Application/SharedCoreProxyTypeRouter.swift": (
        "enum SharedCoreProxyTypeRouter",
        "nativeClassification: ProxyClassification",
        "SharedProxyTypeAdapterError",
        "source: .sharedPrimary",
        "source: .nativeFallback",
        "static func routeLazy(",
        "status: .succeeded",
    ),
    "Sources/Application/SharedCoreProxyTypeRoute.swift": (
        "enum SharedCoreProxyTypeRoute",
        "SharedCoreProxyTypeRouteObservationGate",
        "state.observationGate.shouldReport(observation)",
        "SharedCoreProxyTypeRouter.route(",
        "static func resolveLazy(",
        "SharedCoreProxyTypeRouter.routeLazy(",
        "return result.classification",
    ),
    "Sources/Application/SharedCoreProxyTypeShadow.swift": (
        "SharedCoreProxyTypeShadowObservationGate",
        "state.observationGate.shouldReport(observation)",
        "代理分类影子诊断不得改变仍由原生分类决定的生产结果",
        "return nativeClassification",
    ),
    "Sources/Domain/TrafficMeasurementSession.swift": (
        "resolveProxyType: @escaping ProxyTypeResolver",
        "init(resolveProxyTypeLazily: @escaping LazyProxyTypeResolver)",
        "makeClassifier = { catalog in",
    ),
    "Sources/Application/TrafficMonitoringRun.swift": (
        "resolveProxyTypeLazily: SharedCoreProxyTypeRoute.resolveLazy",
    ),
    "Sources/Application/AppDelegate.swift": (
        "SharedCoreProxyTypeShadow.configure(",
        "SharedCoreProxyTypeRoute.configure(",
        "SharedCoreTrafficDiagnosticReporter.reportProxyTypeShadow",
        "SharedCoreTrafficDiagnosticReporter.reportProxyTypeRoute",
    ),
    "Sources/Infrastructure/Diagnostics/AppDiagnosticEvent.swift": (
        "case sharedCoreProxyTypeShadow(",
        "case sharedCoreProxyTypeRoute(",
        '"event=shared_core.proxy_type_shadow"',
        '"event=shared_core.proxy_type_route"',
        '"source=\\(observation.source.rawValue)"',
        '"status=\\(observation.status.rawValue)"',
    ),
    "Tests/SharedCoreProxyTypeShadowTests.swift": (
        "testRouterReturnsSharedClassificationOnlyForExactMatch",
        "testRouterKeepsNativeResultForUnrecognizedMismatchAndAdapterFailures",
        "testRouteDeduplicatesSourceAndStatusAndIgnoresReporterFailure",
        "testShadowDeduplicatesSourceAndStatusAndIgnoresReporterFailure",
        "testObservationGateKeysBySourceAndStatus",
    ),
    "Tests/SharedCoreProxyTypeLazyRouteTests.swift": (
        "testLazyRouterDoesNotEvaluateFallbackOnSharedSuccess",
        "testLazyRouterEvaluatesFallbackExactlyOnceForUnrecognizedAndSharedFailures",
        "testLazyRouteIgnoresReporterFailureWithoutEvaluatingFallback",
        "status: .succeeded",
    ),
    "MihomoMeter.xcodeproj/project.pbxproj": (
        "SharedCoreProxyTypeShadowObservation.swift in Sources",
        "SharedCoreProxyTypeRouter.swift in Sources",
        "SharedCoreProxyTypeShadow.swift in Sources",
        "SharedCoreProxyTypeRoute.swift in Sources",
        "SharedCoreProxyTypeShadowTests.swift in Sources",
        "SharedCoreProxyTypeLazyRouteTests.swift in Sources",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreProxyTypeRouter.cs": (
        "internal static class SharedCoreProxyTypeRouter",
        "SharedCoreProxyTypeRouteSource.SharedPrimary",
        "SharedCoreProxyTypeRouteSource.NativeFallback",
        "SharedProxyTypeAdapterException",
        "RouteLazy(",
        "SharedCoreProxyTypeRouteStatus.Succeeded",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreProxyTypeShadow.cs": (
        "public enum SharedCoreProxyTypeShadowSource",
        "SharedCoreProxyTypeShadowObservationGate",
        "ObservationGate.ShouldReport(observation)",
        "代理分类影子诊断不得改变仍由原生分类决定的生产结果",
        "return nativeClassification;",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/SharedCoreProxyTypeRoute.cs": (
        "public static class SharedCoreProxyTypeRoute",
        "SharedCoreProxyTypeRouteObservationGate",
        "ObservationGate.ShouldReport(observation)",
        "SharedCoreProxyTypeRouter.Route(",
        "public static ProxyClassification ResolveLazy(",
        "SharedCoreProxyTypeRouter.RouteLazy(",
        "return result.Classification;",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/TrafficMonitoringStream.cs": (
        "SharedCoreProxyTypeRoute.ResolveLazy",
    ),
    "platform/windows/MihomoMeter.Windows.App/Program.cs": (
        "SharedCoreProxyTypeShadow.ConfigureReporter(",
        "SharedCoreProxyTypeRoute.ConfigureReporter(",
        "SharedCoreTrafficDiagnosticReporter.ReportProxyTypeShadow",
        "SharedCoreTrafficDiagnosticReporter.ReportProxyTypeRoute",
    ),
    "platform/windows/MihomoMeter.Windows.App/Diagnostics/SharedCoreTrafficDiagnosticReporter.cs": (
        'SharedCoreProxyTypeRouteStatus.Succeeded => "succeeded"',
    ),
    "platform/windows/MihomoMeter.Windows.App/Diagnostics/StartupConsoleReporter.cs": (
        'event=shared_core.proxy_type_shadow',
        'event=shared_core.proxy_type_route',
        "$\"source={source} status={status}\"",
    ),
    "platform/windows/MihomoMeter.Windows.Tests/SharedCoreProxyTypeShadowTests.cs": (
        "RouterReturnsSharedClassificationOnlyForExactMatch",
        "RouterKeepsNativeResultForUnrecognizedMismatchAndAdapterFailures",
        "RouteDeduplicatesSourceAndStatusAndIgnoresReporterFailure",
        "ShadowDeduplicatesSourceAndStatusAndIgnoresReporterFailure",
        "ObservationGateKeysBySourceAndStatus",
    ),
    "platform/windows/MihomoMeter.Windows.Tests/SharedCoreProxyTypeLazyRouteTests.cs": (
        "LazyRouterDoesNotEvaluateFallbackOnSharedSuccess",
        "LazyRouterEvaluatesFallbackExactlyOnceForUnrecognizedAndSharedFailures",
        "LazyRouteIgnoresReporterFailureWithoutEvaluatingFallback",
        "SharedCoreProxyTypeRouteStatus.Succeeded",
    ),
}

FORBIDDEN_DIRECT_SHARED_CLASSIFIER_MARKERS = {
    "Sources/Domain/ProxyClassifier.swift": (
        "MihomoMeterSharedCoreAdapter",
        "SharedProxyTypeClassification",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Domain/ProxyClassifier.cs": (
        "MihomoMeterSharedCore",
        "SharedProxyTypeClassification",
    ),
}


def validate_shared_core_p2(failures: list[str]) -> None:
    for relative_path, markers in REQUIRED_MARKERS.items():
        path = ROOT / relative_path
        if not path.is_file():
            failures.append(f"缺少 P2 文件：{relative_path}")
            continue
        content = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in content:
                failures.append(f"{relative_path} 缺少 P2 标记：{marker}")

    for relative_path, markers in FORBIDDEN_DIRECT_SHARED_CLASSIFIER_MARKERS.items():
        content = (ROOT / relative_path).read_text(encoding="utf-8")
        for marker in markers:
            if marker in content:
                failures.append(
                    f"{relative_path} 不得绕过 P2 独立路由直接调用共享核心：{marker}"
                )
