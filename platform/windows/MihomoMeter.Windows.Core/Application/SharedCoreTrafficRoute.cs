namespace MihomoMeter.Windows.Core.Application;

public readonly record struct SharedCoreTrafficRouteObservation(
    SharedCoreTrafficFormat Format,
    SharedCoreTrafficRouteSource Source,
    SharedCoreTrafficRouteStatus Status);

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
            RouteStatus(result.Status));
        Report(observation);
        return result.Text;
    }

    public static string ResolveLazy(
        ulong bytes,
        Func<string> nativeFallback,
        SharedCoreTrafficFormat format)
    {
        return ResolveLazy(
            bytes,
            nativeFallback,
            format,
            () => MihomoMeterSharedCore.AbiVersion,
            MihomoMeterSharedCore.ScaleTraffic);
    }

    internal static string ResolveLazy(
        ulong bytes,
        Func<string> nativeFallback,
        SharedCoreTrafficFormat format,
        Func<uint> abiVersion,
        Func<ulong, SharedTrafficScale> scaleTraffic)
    {
        var result = SharedCoreTrafficRouter.RouteLazy(
            bytes,
            nativeFallback,
            format,
            abiVersion,
            scaleTraffic);
        Report(
            new SharedCoreTrafficRouteObservation(
                format,
                result.Source,
                result.Status));
        return result.Text;
    }

    private static void Report(SharedCoreTrafficRouteObservation observation)
    {
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
    }

    private static SharedCoreTrafficRouteStatus RouteStatus(
        SharedCoreTrafficShadowStatus shadowStatus)
    {
        return shadowStatus switch
        {
            SharedCoreTrafficShadowStatus.Matched => SharedCoreTrafficRouteStatus.Matched,
            SharedCoreTrafficShadowStatus.AbiMismatch =>
                SharedCoreTrafficRouteStatus.AbiMismatch,
            SharedCoreTrafficShadowStatus.NativeCallFailed =>
                SharedCoreTrafficRouteStatus.NativeCallFailed,
            SharedCoreTrafficShadowStatus.UnexpectedResult =>
                SharedCoreTrafficRouteStatus.UnexpectedResult,
            SharedCoreTrafficShadowStatus.Mismatch => SharedCoreTrafficRouteStatus.Mismatch,
            SharedCoreTrafficShadowStatus.UnknownFailure =>
                SharedCoreTrafficRouteStatus.UnknownFailure,
            _ => SharedCoreTrafficRouteStatus.UnknownFailure,
        };
    }
}
