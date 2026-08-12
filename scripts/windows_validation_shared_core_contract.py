"""定义 Windows 共享核心影子格式化静态契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WINDOWS_ROOT = ROOT / "platform/windows"
APP_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.App"
CORE_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.Core"
TEST_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.Tests"

SHARED_CORE_REQUIRED_REPOSITORY_FILES = (
    "scripts/windows_validation_shared_core_contract.py",
)

SHARED_CORE_REQUIRED_APP_FILES = (
    "Diagnostics/SharedCoreTrafficDiagnosticReporter.cs",
    "Presentation/NotificationAreaRealtimeController.cs",
    "Presentation/TrafficDisplayFormatter.cs",
)

SHARED_CORE_REQUIRED_CORE_FILES = (
    "Application/MihomoMeterSharedCore.cs",
    "Application/SharedCoreProxyTypeRouter.cs",
    "Application/SharedCoreProxyTypeRoute.cs",
    "Application/SharedCoreProxyTypeShadow.cs",
    "Application/SharedCoreRuntimeProbe.cs",
    "Application/SharedCoreTrafficRoute.cs",
    "Application/SharedCoreTrafficRouter.cs",
    "Application/SharedCoreTrafficDisplayFormatter.cs",
    "Application/SharedCoreTrafficShadow.cs",
    "Application/SharedCoreTrafficShadowComparator.cs",
    "Application/TrafficDisplayUnits.cs",
)

SHARED_CORE_REQUIRED_TEST_FILES = (
    "MihomoMeterSharedCoreTests.cs",
    "SharedCoreProxyTypeShadowTests.cs",
    "SharedCoreProxyTypeLazyRouteTests.cs",
    "SharedCoreRuntimeProbeTests.cs",
    "SharedCoreTrafficLazyRouteTests.cs",
    "SharedCoreTrafficRouterTests.cs",
    "SharedCoreTrafficShadowComparatorTests.cs",
    "TrafficDisplayUnitsTests.cs",
)

SHARED_CORE_REQUIRED_CODE_MARKERS = {
    APP_ROOT / "Program.cs": (
        "ReportSharedCoreRuntimeStatus();",
        "SharedCoreProxyTypeShadow.ConfigureReporter(",
        "SharedCoreProxyTypeRoute.ConfigureReporter(",
        "SharedCoreTrafficDiagnosticReporter.ReportProxyTypeShadow",
        "SharedCoreTrafficDiagnosticReporter.ReportProxyTypeRoute",
        "SharedCoreTrafficShadow.ConfigureReporter(",
        "SharedCoreTrafficDiagnosticReporter.ReportShadow",
    ),
    APP_ROOT / "Diagnostics/StartupConsoleReporter.cs": (
        "public static void ProxyTypeShadow(string source, string status)",
        'event=shared_core.proxy_type_shadow',
        "public static void ProxyTypeRoute(string source, string status)",
        'event=shared_core.proxy_type_route',
        "public static void TrafficShadow(string format, string result)",
        'event=shared_core.traffic_shadow',
    ),
    APP_ROOT / "Diagnostics/SharedCoreTrafficDiagnosticReporter.cs": (
        "ReportProxyTypeShadow(SharedCoreProxyTypeShadowObservation observation)",
        "ReportProxyTypeRoute(SharedCoreProxyTypeRouteObservation observation)",
        'SharedCoreProxyTypeRouteStatus.Unrecognized => "unrecognized"',
        'SharedCoreProxyTypeRouteStatus.Succeeded => "succeeded"',
        "StartupConsoleReporter.ProxyTypeShadow(",
        'SharedCoreTrafficShadowStatus.Matched => "matched"',
        "StartupConsoleReporter.TrafficShadow(",
    ),
    APP_ROOT / "Presentation/NotificationAreaRealtimeController.cs": (
        "TrafficDisplayFormatter.CompactRate(",
        "RoutingStatusPresentation",
        "TUN Stack",
        "自动路由",
        "局域网访问",
        "Mixed Port",
        "SnapshotChanged",
    ),
    APP_ROOT / "Presentation/TrafficDisplayFormatter.cs": (
        "SharedCoreTrafficRoute.ResolveLazy(",
        "SharedCoreTrafficFormat.ByteCount",
        "SharedCoreTrafficFormat.Rate",
        "SharedCoreTrafficFormat.CompactRate",
    ),
    CORE_ROOT / "Application/TrafficDisplayUnits.cs": (
        "public static string ByteCount(ulong bytes)",
        "public static string Rate(ulong bytesPerSecond)",
        "public static string CompactRate(ulong? bytesPerSecond)",
        "CultureInfo.InvariantCulture",
    ),
    CORE_ROOT / "Application/SharedCoreTrafficDisplayFormatter.cs": (
        "SharedCoreTrafficFormat.ByteCount",
        "SharedCoreTrafficFormat.Rate",
        "SharedCoreTrafficFormat.CompactRate",
    ),
    CORE_ROOT / "Domain/ProxyClassifier.cs": (
        "Func<string, ProxyClassification, ProxyClassification>? resolveProxyType",
        "public delegate ProxyClassification LazyProxyTypeResolver",
        "_resolveProxyType!(rawType, nativeClassification)",
        "_resolveProxyTypeLazily(rawType, () => ClassifyNatively(rawType))",
    ),
    CORE_ROOT / "Application/TrafficMeasurementSession.cs": (
        "Func<string, ProxyClassification, ProxyClassification>? resolveProxyType",
        "LazyProxyTypeResolver resolveProxyTypeLazily",
        "new ProxyClassifier(nextCatalog, resolveProxyTypeLazily)",
    ),
    CORE_ROOT / "Application/TrafficMonitoringStream.cs": (
        "SharedCoreProxyTypeRoute.ResolveLazy",
    ),
    CORE_ROOT / "Application/SharedCoreProxyTypeRouter.cs": (
        "SharedCoreProxyTypeRouteSource.SharedPrimary",
        "SharedCoreProxyTypeRouteSource.NativeFallback",
        "SharedCoreProxyTypeRouteStatus.Unrecognized",
        "SharedCoreProxyTypeRouteStatus.Succeeded",
        "RouteLazy(",
        "SharedProxyTypeAdapterException",
        "nativeClassification",
    ),
    CORE_ROOT / "Application/SharedCoreProxyTypeShadow.cs": (
        "public enum SharedCoreProxyTypeShadowSource",
        "SharedCoreProxyTypeShadowObservationGate",
        "ObservationGate.ShouldReport(observation)",
        "代理分类影子诊断不得改变仍由原生分类决定的生产结果",
        "return nativeClassification;",
    ),
    CORE_ROOT / "Application/SharedCoreProxyTypeRoute.cs": (
        "public static class SharedCoreProxyTypeRoute",
        "SharedCoreProxyTypeRouteObservationGate",
        "ObservationGate.ShouldReport(observation)",
        "SharedCoreProxyTypeRouter.Route(",
        "public static ProxyClassification ResolveLazy(",
        "SharedCoreProxyTypeRouter.RouteLazy(",
        "return result.Classification;",
    ),
    CORE_ROOT / "Application/SharedCoreTrafficShadow.cs": (
        "public static void ConfigureReporter(",
        "SharedCoreTrafficShadowObservationGate",
        "ObservationGate.Reset()",
        "ObservationGate.ShouldReport(observation)",
        "SharedCoreTrafficRouter.Route(",
        "影子诊断不得影响仍由原生算法决定的生产输出",
        "return nativeText;",
    ),
    CORE_ROOT / "Application/SharedCoreTrafficShadowComparator.cs": (
        "SharedCoreTrafficRouter.Route(",
        ").Status",
    ),
    CORE_ROOT / "Application/SharedCoreTrafficRouter.cs": (
        "SharedCoreTrafficDisplayFormatter.Format(",
        "SharedCoreTrafficRouteSource.SharedPrimary",
        "SharedCoreTrafficRouteSource.NativeFallback",
    ),
    TEST_ROOT / "SharedCoreTrafficShadowComparatorTests.cs": (
        "ComparatorMatchesEveryProductionFormat",
        "ComparatorStopsBeforeScalingForAbiMismatch",
        "ComparatorReportsMismatchWithoutReturningSharedText",
        "ObservationGateReportsEachFormatAndStatusOnce",
        "ShadowReportsMatchedObservationOnce",
        "ShadowReturnsNativeTextWhenDiagnosticReporterFails",
    ),
    TEST_ROOT / "SharedCoreTrafficRouterTests.cs": (
        "RouterReturnsSharedTextOnlyForExactMatch",
        "RouterFallsBackToNativeTextForMismatchAndSharedFailures",
        "ShadowAlwaysReturnsNativeTextWithInjectedSharedCandidate",
        "RouteDeduplicatesObservationsAndIgnoresReporterFailure",
        "SharedCoreTrafficRouteStatus.Matched",
    ),
    TEST_ROOT / "SharedCoreTrafficLazyRouteTests.cs": (
        "LazyRouterDoesNotEvaluateFallbackOnSuccess",
        "LazyRouterStopsBeforeScalingForAbiMismatch",
        "LazyRouterEvaluatesFallbackExactlyOnceForSharedFailures",
        "LazyRouteIgnoresReporterFailureWithoutEvaluatingFallback",
        "DeterministicDifferentialMatchesNativeFormatters",
        "10_000",
        "SplitMix64",
    ),
    TEST_ROOT / "MihomoMeterSharedCoreTests.cs": (
        "TrafficDisplayUnits.ByteCount(bytes)",
        "TrafficDisplayUnits.Rate(bytes)",
        "TrafficDisplayUnits.CompactRate(bytes)",
        "SharedCoreTrafficDisplayFormatter.Format(",
    ),
    TEST_ROOT / "SharedCoreProxyTypeShadowTests.cs": (
        "RouterReturnsSharedClassificationOnlyForExactMatch",
        "RouterKeepsNativeResultForUnrecognizedMismatchAndAdapterFailures",
        "RouteDeduplicatesSourceAndStatusAndIgnoresReporterFailure",
        "ShadowDeduplicatesSourceAndStatusAndIgnoresReporterFailure",
        "ObservationGateKeysBySourceAndStatus",
    ),
    TEST_ROOT / "SharedCoreProxyTypeLazyRouteTests.cs": (
        "LazyRouterDoesNotEvaluateFallbackOnSharedSuccess",
        "LazyRouterEvaluatesFallbackExactlyOnceForUnrecognizedAndSharedFailures",
        "LazyRouteIgnoresReporterFailureWithoutEvaluatingFallback",
        "SharedCoreProxyTypeRouteStatus.Succeeded",
    ),
}
