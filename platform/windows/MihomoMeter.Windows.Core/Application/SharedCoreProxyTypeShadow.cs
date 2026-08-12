using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public enum SharedCoreProxyTypeShadowSource
{
    SharedShadow,
    NativeFallback,
}

public readonly record struct SharedCoreProxyTypeShadowObservation(
    SharedCoreProxyTypeShadowSource Source,
    SharedCoreProxyTypeRouteStatus Status);

internal sealed class SharedCoreProxyTypeShadowObservationGate
{
    private readonly HashSet<SharedCoreProxyTypeShadowObservation> _reportedObservations = [];

    public bool ShouldReport(SharedCoreProxyTypeShadowObservation observation)
    {
        return _reportedObservations.Add(observation);
    }

    public void Reset()
    {
        _reportedObservations.Clear();
    }
}

public static class SharedCoreProxyTypeShadow
{
    private static readonly object StateLock = new();
    private static readonly SharedCoreProxyTypeShadowObservationGate ObservationGate = new();
    private static Action<SharedCoreProxyTypeShadowObservation>? _reporter;

    public static void ConfigureReporter(
        Action<SharedCoreProxyTypeShadowObservation>? reporter)
    {
        lock (StateLock)
        {
            _reporter = reporter;
            ObservationGate.Reset();
        }
    }

    public static ProxyClassification Observe(
        string rawType,
        ProxyClassification nativeClassification)
    {
        return Observe(
            rawType,
            nativeClassification,
            MihomoMeterSharedCore.ClassifyProxyType);
    }

    internal static ProxyClassification Observe(
        string rawType,
        ProxyClassification nativeClassification,
        Func<string, SharedProxyTypeClassification> classifyProxyType)
    {
        var result = SharedCoreProxyTypeRouter.Route(
            rawType,
            nativeClassification,
            classifyProxyType);
        var observation = new SharedCoreProxyTypeShadowObservation(
            ShadowSource(result.Source),
            result.Status);
        Action<SharedCoreProxyTypeShadowObservation>? reporter;
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
            // 代理分类影子诊断不得改变仍由原生分类决定的生产结果。
        }
        return nativeClassification;
    }

    private static SharedCoreProxyTypeShadowSource ShadowSource(
        SharedCoreProxyTypeRouteSource source)
    {
        return source switch
        {
            SharedCoreProxyTypeRouteSource.SharedPrimary =>
                SharedCoreProxyTypeShadowSource.SharedShadow,
            SharedCoreProxyTypeRouteSource.NativeFallback =>
                SharedCoreProxyTypeShadowSource.NativeFallback,
            _ => SharedCoreProxyTypeShadowSource.NativeFallback,
        };
    }
}
