using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Core.Application;

public sealed record TrafficMeasurementResult(
    TrafficRateWindow? RateWindow,
    bool RequiresCatalogRefresh,
    bool CountersReset);

public sealed class TrafficMeasurementSession
{
    private readonly TimeProvider _timeProvider;
    private readonly ConnectionDeltaTracker _deltaTracker = new();
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
        var requiresCatalogRefresh = trafficSnapshot.Connections.Any(connection =>
            _classifier.Classify(connection.Chains).UnknownReason
                == UnknownTrafficReason.MissingCatalogEntry);

        var now = _timeProvider.GetTimestamp();
        var elapsedSeconds = _lastSnapshotTimestamp is null
            ? (double?)null
            : _timeProvider.GetElapsedTime(_lastSnapshotTimestamp.Value, now).TotalSeconds;
        _lastSnapshotTimestamp = now;

        var transition = _deltaTracker.Consume(trafficSnapshot, _classifier);
        switch (transition.Status)
        {
            case ConnectionDeltaStatus.BaselineEstablished:
                return new TrafficMeasurementResult(null, requiresCatalogRefresh, false);
            case ConnectionDeltaStatus.CountersReset:
                _rateAggregator.Reset();
                return new TrafficMeasurementResult(null, requiresCatalogRefresh, true);
            case ConnectionDeltaStatus.Delta when transition.Batch is not null:
                var rateWindow = elapsedSeconds is null
                    ? null
                    : _rateAggregator.Consume(
                        transition.Batch.Traffic,
                        elapsedSeconds.Value);
                return new TrafficMeasurementResult(
                    rateWindow,
                    requiresCatalogRefresh,
                    false);
            default:
                return new TrafficMeasurementResult(null, requiresCatalogRefresh, false);
        }
    }

    public void ResetBaseline()
    {
        _deltaTracker.Reset();
        _rateAggregator.Reset();
        _lastSnapshotTimestamp = null;
    }
}
