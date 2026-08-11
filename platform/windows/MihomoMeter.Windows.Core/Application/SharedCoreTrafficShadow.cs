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

public static class SharedCoreTrafficShadow
{
    private static readonly object ReporterLock = new();
    private static Action<SharedCoreTrafficShadowObservation>? _reporter;

    public static void ConfigureReporter(
        Action<SharedCoreTrafficShadowObservation>? reporter)
    {
        lock (ReporterLock)
        {
            _reporter = reporter;
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
        if (status == SharedCoreTrafficShadowStatus.Matched)
        {
            return nativeText;
        }

        Action<SharedCoreTrafficShadowObservation>? reporter;
        lock (ReporterLock)
        {
            reporter = _reporter;
        }
        try
        {
            reporter?.Invoke(new SharedCoreTrafficShadowObservation(format, status));
        }
        catch
        {
            // 影子诊断不得影响仍由原生算法决定的生产输出。
        }
        return nativeText;
    }
}
