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
    "SharedCoreRuntimeProbeTests.cs",
    "SharedCoreTrafficLazyRouteTests.cs",
    "SharedCoreTrafficRouterTests.cs",
    "SharedCoreTrafficShadowComparatorTests.cs",
    "TrafficDisplayUnitsTests.cs",
)

SHARED_CORE_REQUIRED_CODE_MARKERS = {
    APP_ROOT / "Program.cs": (
        "ReportSharedCoreRuntimeStatus();",
        "SharedCoreTrafficShadow.ConfigureReporter(",
        "SharedCoreTrafficDiagnosticReporter.ReportShadow",
    ),
    APP_ROOT / "Diagnostics/StartupConsoleReporter.cs": (
        "public static void TrafficShadow(string format, string result)",
        'event=shared_core.traffic_shadow',
    ),
    APP_ROOT / "Diagnostics/SharedCoreTrafficDiagnosticReporter.cs": (
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
        "SharedCoreTrafficRoute.Resolve(",
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
}
