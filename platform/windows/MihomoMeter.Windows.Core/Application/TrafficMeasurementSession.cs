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
    IReadOnlyList<LiveTrafficConnection>? DirectConnections = null)
{
    public IReadOnlyList<LiveTrafficConnection> LiveProxyConnections =>
        ProxyConnections ?? Array.Empty<LiveTrafficConnection>();

    public IReadOnlyList<LiveTrafficConnection> LiveDirectConnections =>
        DirectConnections ?? Array.Empty<LiveTrafficConnection>();
}

public sealed class TrafficMeasurementSession
{
    private readonly TimeProvider _timeProvider;
    private readonly ConnectionDeltaTracker _deltaTracker = new();
    private readonly ConnectionAttributionCoverageTracker _attributionCoverageTracker = new();
    private readonly ConnectionRateAggregator _proxyConnectionRates = new();
    private readonly ConnectionRateAggregator _directConnectionRates = new();
    private readonly TrafficRateAggregator _rateAggregator = new();
    private ProxyClassifier _classifier;
    private long? _lastSnapshotTimestamp;

    public TrafficMeasurementSession(
        ProxyCatalog catalog,
        TimeProvider? timeProvider = null)
    {
        _classifier = new ProxyClassifier(catalog);
        _timeProvider = timeProvider ?? TimeProvider.System;
    }

    public void UpdateCatalog(ProxyCatalog catalog)
    {
        _classifier = new ProxyClassifier(catalog);
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
                    _directConnectionRates.LiveConnections);
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
                    Array.Empty<LiveTrafficConnection>());
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
                    liveDirectConnections);
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
