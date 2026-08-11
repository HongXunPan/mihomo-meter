using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Diagnostics;

internal static class SharedCoreTrafficShadowReporter
{
    private static readonly object ReportedObservationsLock = new();
    private static readonly HashSet<SharedCoreTrafficShadowObservation> ReportedObservations = [];

    public static void Report(SharedCoreTrafficShadowObservation observation)
    {
        if (observation.Status == SharedCoreTrafficShadowStatus.Matched)
        {
            return;
        }

        lock (ReportedObservationsLock)
        {
            if (!ReportedObservations.Add(observation))
            {
                return;
            }
        }

        StartupConsoleReporter.TrafficShadow(
            FormatText(observation.Format),
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

    private static string StatusText(SharedCoreTrafficShadowStatus status)
    {
        return status switch
        {
            SharedCoreTrafficShadowStatus.AbiMismatch => "abi_mismatch",
            SharedCoreTrafficShadowStatus.NativeCallFailed => "native_call_failed",
            SharedCoreTrafficShadowStatus.UnexpectedResult => "unexpected_result",
            SharedCoreTrafficShadowStatus.Mismatch => "mismatch",
            SharedCoreTrafficShadowStatus.UnknownFailure => "unknown_failure",
            _ => "unknown",
        };
    }
}
