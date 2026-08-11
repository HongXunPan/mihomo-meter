namespace MihomoMeter.Windows.Core.Application;

public readonly record struct SharedCoreTrafficRouteObservation(
    SharedCoreTrafficFormat Format,
    SharedCoreTrafficRouteSource Source,
    SharedCoreTrafficShadowStatus Status);

internal sealed class SharedCoreTrafficRouteObservationGate
{
    private readonly HashSet<SharedCoreTrafficRouteObservation> _reportedObservations = [];

    public bool ShouldReport(SharedCoreTrafficRouteObservation observation)
    {
        return _reportedObservations.Add(observation);
    }

    public void Reset()
    {
        _reportedObservations.Clear();
    }
}

public static class SharedCoreTrafficRoute
{
    private static readonly object StateLock = new();
    private static readonly SharedCoreTrafficRouteObservationGate ObservationGate = new();
    private static Action<SharedCoreTrafficRouteObservation>? _reporter;

    public static void ConfigureReporter(
        Action<SharedCoreTrafficRouteObservation>? reporter)
    {
        lock (StateLock)
        {
            _reporter = reporter;
            ObservationGate.Reset();
        }
    }

    public static string Resolve(
        ulong bytes,
        string nativeText,
        SharedCoreTrafficFormat format)
    {
        return Resolve(
            bytes,
            nativeText,
            format,
            () => MihomoMeterSharedCore.AbiVersion,
            MihomoMeterSharedCore.ScaleTraffic);
    }

    internal static string Resolve(
        ulong bytes,
        string nativeText,
        SharedCoreTrafficFormat format,
        Func<uint> abiVersion,
        Func<ulong, SharedTrafficScale> scaleTraffic)
    {
        var result = SharedCoreTrafficRouter.Route(
            bytes,
            nativeText,
            format,
            abiVersion,
            scaleTraffic);
        var observation = new SharedCoreTrafficRouteObservation(
            format,
            result.Source,
            result.Status);
        Action<SharedCoreTrafficRouteObservation>? reporter;
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
            // 路由诊断不得改变共享主路径或原生回退结果。
        }
        return result.Text;
    }
}
