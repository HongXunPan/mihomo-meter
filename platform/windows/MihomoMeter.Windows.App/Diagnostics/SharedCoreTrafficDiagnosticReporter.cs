using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Diagnostics;

internal static class SharedCoreTrafficDiagnosticReporter
{
    public static void ReportShadow(SharedCoreTrafficShadowObservation observation)
    {
        StartupConsoleReporter.TrafficShadow(
            FormatText(observation.Format),
            StatusText(observation.Status));
    }

    public static void ReportRoute(SharedCoreTrafficRouteObservation observation)
    {
        StartupConsoleReporter.TrafficRoute(
            FormatText(observation.Format),
            SourceText(observation.Source),
            StatusText(observation.Status));
    }

    private static string FormatText(SharedCoreTrafficFormat format)
    {
        return format switch
        {
            SharedCoreTrafficFormat.ByteCount => "byte_count",
            SharedCoreTrafficFormat.Rate => "rate",
            SharedCoreTrafficFormat.CompactRate => "compact_rate",
            _ => "unknown",
        };
    }

    private static string SourceText(SharedCoreTrafficRouteSource source)
    {
        return source switch
        {
            SharedCoreTrafficRouteSource.SharedPrimary => "shared_primary",
            SharedCoreTrafficRouteSource.NativeFallback => "native_fallback",
            _ => "unknown",
        };
    }

    private static string StatusText(SharedCoreTrafficShadowStatus status)
    {
        return status switch
        {
            SharedCoreTrafficShadowStatus.Matched => "matched",
            SharedCoreTrafficShadowStatus.AbiMismatch => "abi_mismatch",
            SharedCoreTrafficShadowStatus.NativeCallFailed => "native_call_failed",
            SharedCoreTrafficShadowStatus.UnexpectedResult => "unexpected_result",
            SharedCoreTrafficShadowStatus.Mismatch => "mismatch",
            SharedCoreTrafficShadowStatus.UnknownFailure => "unknown_failure",
            _ => "unknown",
        };
    }

    private static string StatusText(SharedCoreTrafficRouteStatus status)
    {
        return status switch
        {
            SharedCoreTrafficRouteStatus.Matched => "matched",
            SharedCoreTrafficRouteStatus.Succeeded => "succeeded",
            SharedCoreTrafficRouteStatus.AbiMismatch => "abi_mismatch",
            SharedCoreTrafficRouteStatus.NativeCallFailed => "native_call_failed",
            SharedCoreTrafficRouteStatus.UnexpectedResult => "unexpected_result",
            SharedCoreTrafficRouteStatus.Mismatch => "mismatch",
            SharedCoreTrafficRouteStatus.UnknownFailure => "unknown_failure",
            _ => "unknown",
        };
    }
}
