using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Core.Application;

public sealed record TrafficMeasurementResult(
    TrafficRateWindow? RateWindow,
    bool RequiresCatalogRefresh,
    bool CountersReset,
    TrafficLedgerObservation LedgerObservation,
    ConnectionAttributionCoverage AttributionCoverage = default,
    IReadOnlyList<LiveTrafficConnection>? ProxyConnections = null,
    IReadOnlyList<LiveTrafficConnection>? DirectConnections = null,
    IReadOnlyList<ConnectionAttributionDelta>? AttributionDeltas = null,
    IReadOnlyList<string>? ProxyLeaves = null,
    IReadOnlyList<string>? RuleTypes = null)
{
    public IReadOnlyList<LiveTrafficConnection> LiveProxyConnections =>
        ProxyConnections ?? Array.Empty<LiveTrafficConnection>();

    public IReadOnlyList<LiveTrafficConnection> LiveDirectConnections =>
        DirectConnections ?? Array.Empty<LiveTrafficConnection>();

    public IReadOnlyList<ConnectionAttributionDelta> ConnectionAttributionDeltas =>
        AttributionDeltas ?? Array.Empty<ConnectionAttributionDelta>();

    public IReadOnlyList<string> ActiveProxyLeaves =>
        ProxyLeaves ?? Array.Empty<string>();

    public IReadOnlyList<string> ActiveRuleTypes =>
        RuleTypes ?? Array.Empty<string>();
}

public sealed class TrafficMeasurementSession
{
    private readonly TimeProvider _timeProvider;
    private readonly ConnectionDeltaTracker _deltaTracker = new();
    private readonly ConnectionAttributionCoverageTracker _attributionCoverageTracker = new();
    private readonly ConnectionRateAggregator _proxyConnectionRates = new();
    private readonly ConnectionRateAggregator _directConnectionRates = new();
    private readonly TrafficRateAggregator _rateAggregator = new();
    private readonly Func<string, ProxyClassification, ProxyClassification> _resolveProxyType;
    private ProxyClassifier _classifier;
    private long? _lastSnapshotTimestamp;

    public TrafficMeasurementSession(
        ProxyCatalog catalog,
        TimeProvider? timeProvider = null,
        Func<string, ProxyClassification, ProxyClassification>? resolveProxyType = null)
    {
        _resolveProxyType = resolveProxyType ?? ((_, nativeClassification) =>
            nativeClassification);
        _classifier = new ProxyClassifier(catalog, _resolveProxyType);
        _timeProvider = timeProvider ?? TimeProvider.System;
    }

    public void UpdateCatalog(ProxyCatalog catalog)
    {
        _classifier = new ProxyClassifier(catalog, _resolveProxyType);
    }

    public TrafficMeasurementResult Consume(MihomoConnectionsSnapshot snapshot)
    {
        var trafficSnapshot = snapshot.ToTrafficSnapshot();
        var classifications = trafficSnapshot.Connections.Select(connection => new
        {
            Connection = connection,
            Classification = _classifier.Classify(connection.Chains),
        }).ToArray();
        var requiresCatalogRefresh = classifications.Any(item =>
            item.Classification.UnknownReason == UnknownTrafficReason.MissingCatalogEntry);
        var proxyConnections = classifications
            .Where(item => item.Classification.Category == TrafficCategory.Proxy)
            .Select(item => item.Connection)
            .ToArray();
        var directConnections = classifications
            .Where(item => item.Classification.Category == TrafficCategory.Direct)
            .Select(item => item.Connection)
            .ToArray();
        var activeProxyLeaves = proxyConnections
            .Select(connection => connection.Chains.FirstOrDefault()?.Trim())
            .Where(value => !string.IsNullOrEmpty(value))
            .Select(value => value!)
            .Distinct(StringComparer.Ordinal)
            .OrderBy(value => value, StringComparer.Ordinal)
            .ToArray();
        var activeRuleTypes = trafficSnapshot.Connections
            .Select(connection => connection.Rule?.Trim())
            .Where(value => !string.IsNullOrEmpty(value))
            .Select(value => value!)
            .Distinct(StringComparer.Ordinal)
            .OrderBy(value => value, StringComparer.Ordinal)
            .ToArray();
        var attributionCoverage = _attributionCoverageTracker.Consume(proxyConnections);

        var now = _timeProvider.GetTimestamp();
        var elapsedSeconds = _lastSnapshotTimestamp is null
            ? (double?)null
            : _timeProvider.GetElapsedTime(_lastSnapshotTimestamp.Value, now).TotalSeconds;
        _lastSnapshotTimestamp = now;

        var transition = _deltaTracker.Consume(trafficSnapshot, _classifier);
        switch (transition.Status)
        {
            case ConnectionDeltaStatus.BaselineEstablished:
                _proxyConnectionRates.EstablishBaseline(proxyConnections);
                _directConnectionRates.EstablishBaseline(directConnections);
                return new TrafficMeasurementResult(
                    null,
                    requiresCatalogRefresh,
                    false,
                    new TrafficLedgerObservation(
                        _timeProvider.GetUtcNow(),
                        trafficSnapshot.KernelTotal,
                        new TrafficLedgerBaselineEstablished()),
                    attributionCoverage,
                    _proxyConnectionRates.LiveConnections,
                    _directConnectionRates.LiveConnections,
                    ProxyLeaves: activeProxyLeaves,
                    RuleTypes: activeRuleTypes);
            case ConnectionDeltaStatus.CountersReset:
                _rateAggregator.Reset();
                _proxyConnectionRates.Reset();
                _directConnectionRates.Reset();
                _attributionCoverageTracker.Reset();
                return new TrafficMeasurementResult(
                    null,
                    requiresCatalogRefresh,
                    true,
                    new TrafficLedgerObservation(
                        _timeProvider.GetUtcNow(),
                        trafficSnapshot.KernelTotal,
                        new TrafficLedgerCountersReset()),
                    ConnectionAttributionCoverage.Empty,
                    Array.Empty<LiveTrafficConnection>(),
                    Array.Empty<LiveTrafficConnection>(),
                    ProxyLeaves: activeProxyLeaves,
                    RuleTypes: activeRuleTypes);
            case ConnectionDeltaStatus.Delta when transition.Batch is not null:
                var rateWindow = elapsedSeconds is null
                    ? null
                    : _rateAggregator.Consume(
                        transition.Batch.Traffic,
                        elapsedSeconds.Value);
                var liveProxyConnections = _proxyConnectionRates.Consume(
                    proxyConnections,
                    transition.Batch.Connections
                        .Where(delta => delta.Category == TrafficCategory.Proxy)
                        .ToArray(),
                    elapsedSeconds);
                var liveDirectConnections = _directConnectionRates.Consume(
                    directConnections,
                    transition.Batch.Connections
                        .Where(delta => delta.Category == TrafficCategory.Direct)
                        .ToArray(),
                    elapsedSeconds);
                var attributionDeltas = transition.Batch.Connections
                    .Where(connection =>
                        connection.Category == TrafficCategory.Proxy
                        && connection.Bytes.Total > 0)
                    .Select(connection => new ConnectionAttributionDelta(
                        connection.Metadata,
                        connection.Bytes))
                    .ToArray();
                return new TrafficMeasurementResult(
                    rateWindow,
                    requiresCatalogRefresh,
                    false,
                    new TrafficLedgerObservation(
                        _timeProvider.GetUtcNow(),
                        trafficSnapshot.KernelTotal,
                        new TrafficLedgerDelta(transition.Batch.Traffic)),
                    attributionCoverage,
                    liveProxyConnections,
                    liveDirectConnections,
                    attributionDeltas,
                    activeProxyLeaves,
                    activeRuleTypes);
            default:
                throw new InvalidOperationException("连接差值状态缺少对应账本观测。");
        }
    }

    public void ResetBaseline()
    {
        _deltaTracker.Reset();
        _attributionCoverageTracker.Reset();
        _rateAggregator.Reset();
        _proxyConnectionRates.Reset();
        _directConnectionRates.Reset();
        _lastSnapshotTimestamp = null;
    }
}
