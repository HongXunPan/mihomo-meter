using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public readonly record struct SharedCoreProxyTypeRouteObservation(
    SharedCoreProxyTypeRouteSource Source,
    SharedCoreProxyTypeRouteStatus Status);

internal sealed class SharedCoreProxyTypeRouteObservationGate
{
    private readonly HashSet<SharedCoreProxyTypeRouteObservation> _reportedObservations = [];

    public bool ShouldReport(SharedCoreProxyTypeRouteObservation observation)
    {
        return _reportedObservations.Add(observation);
    }

    public void Reset()
    {
        _reportedObservations.Clear();
    }
}

public static class SharedCoreProxyTypeRoute
{
    private static readonly object StateLock = new();
    private static readonly SharedCoreProxyTypeRouteObservationGate ObservationGate = new();
    private static Action<SharedCoreProxyTypeRouteObservation>? _reporter;

    public static void ConfigureReporter(Action<SharedCoreProxyTypeRouteObservation>? reporter)
    {
        lock (StateLock)
        {
            _reporter = reporter;
            ObservationGate.Reset();
        }
    }

    public static ProxyClassification Resolve(
        string rawType,
        ProxyClassification nativeClassification)
    {
        return Resolve(
            rawType,
            nativeClassification,
            MihomoMeterSharedCore.ClassifyProxyType);
    }

    internal static ProxyClassification Resolve(
        string rawType,
        ProxyClassification nativeClassification,
        Func<string, SharedProxyTypeClassification> classifyProxyType)
    {
        var result = SharedCoreProxyTypeRouter.Route(
            rawType,
            nativeClassification,
            classifyProxyType);
        Report(new SharedCoreProxyTypeRouteObservation(result.Source, result.Status));
        return result.Classification;
    }

    public static ProxyClassification ResolveLazy(
        string rawType,
        Func<ProxyClassification> nativeFallback)
    {
        return ResolveLazy(
            rawType,
            nativeFallback,
            MihomoMeterSharedCore.ClassifyProxyType);
    }

    internal static ProxyClassification ResolveLazy(
        string rawType,
        Func<ProxyClassification> nativeFallback,
        Func<string, SharedProxyTypeClassification> classifyProxyType)
    {
        var result = SharedCoreProxyTypeRouter.RouteLazy(
            rawType,
            nativeFallback,
            classifyProxyType);
        Report(new SharedCoreProxyTypeRouteObservation(result.Source, result.Status));
        return result.Classification;
    }

    private static void Report(SharedCoreProxyTypeRouteObservation observation)
    {
        Action<SharedCoreProxyTypeRouteObservation>? reporter;
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
            // 路由诊断不得改变共享分类或原生回退结果。
        }
    }
}
