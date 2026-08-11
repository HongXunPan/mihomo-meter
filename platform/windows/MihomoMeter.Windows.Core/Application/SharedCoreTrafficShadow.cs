namespace MihomoMeter.Windows.Core.Application;

public enum SharedCoreTrafficFormat
{
    ByteCount,
    Rate,
    CompactRate,
}

public enum SharedCoreTrafficShadowStatus
{
    Matched,
    AbiMismatch,
    NativeCallFailed,
    UnexpectedResult,
    Mismatch,
    UnknownFailure,
}

public readonly record struct SharedCoreTrafficShadowObservation(
    SharedCoreTrafficFormat Format,
    SharedCoreTrafficShadowStatus Status);

internal sealed class SharedCoreTrafficShadowObservationGate
{
    private readonly HashSet<SharedCoreTrafficShadowObservation> _reportedObservations = [];

    public bool ShouldReport(SharedCoreTrafficShadowObservation observation)
    {
        return _reportedObservations.Add(observation);
    }

    public void Reset()
    {
        _reportedObservations.Clear();
    }
}

public static class SharedCoreTrafficShadow
{
    private static readonly object StateLock = new();
    private static readonly SharedCoreTrafficShadowObservationGate ObservationGate = new();
    private static Action<SharedCoreTrafficShadowObservation>? _reporter;

    public static void ConfigureReporter(
        Action<SharedCoreTrafficShadowObservation>? reporter)
    {
        lock (StateLock)
        {
            _reporter = reporter;
            ObservationGate.Reset();
        }
    }

    public static string Observe(
        ulong bytes,
        string nativeText,
        SharedCoreTrafficFormat format)
    {
        var status = SharedCoreTrafficShadowComparator.Compare(
            bytes,
            nativeText,
            format);
        var observation = new SharedCoreTrafficShadowObservation(format, status);
        Action<SharedCoreTrafficShadowObservation>? reporter;
        lock (StateLock)
        {
            reporter = _reporter is not null && ObservationGate.ShouldReport(observation)
                ? _reporter
                : null;
        }
        try
        {
            reporter?.Invoke(observation);
        }
        catch
        {
            // 影子诊断不得影响仍由原生算法决定的生产输出。
        }
        return nativeText;
    }
}
