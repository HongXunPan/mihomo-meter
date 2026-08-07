using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Core.Application;

public sealed record TrafficMeasurementResult(
    TrafficRateWindow? RateWindow,
    bool RequiresCatalogRefresh,
    bool CountersReset,
    TrafficLedgerObservation LedgerObservation);

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
                return new TrafficMeasurementResult(
                    null,
                    requiresCatalogRefresh,
                    false,
                    new TrafficLedgerObservation(
                        _timeProvider.GetUtcNow(),
                        trafficSnapshot.KernelTotal,
                        new TrafficLedgerBaselineEstablished()));
            case ConnectionDeltaStatus.CountersReset:
                _rateAggregator.Reset();
                return new TrafficMeasurementResult(
                    null,
                    requiresCatalogRefresh,
                    true,
                    new TrafficLedgerObservation(
                        _timeProvider.GetUtcNow(),
                        trafficSnapshot.KernelTotal,
                        new TrafficLedgerCountersReset()));
            case ConnectionDeltaStatus.Delta when transition.Batch is not null:
                var rateWindow = elapsedSeconds is null
                    ? null
                    : _rateAggregator.Consume(
                        transition.Batch.Traffic,
                        elapsedSeconds.Value);
                return new TrafficMeasurementResult(
                    rateWindow,
                    requiresCatalogRefresh,
                    false,
                    new TrafficLedgerObservation(
                        _timeProvider.GetUtcNow(),
                        trafficSnapshot.KernelTotal,
                        new TrafficLedgerDelta(transition.Batch.Traffic)));
            default:
                throw new InvalidOperationException("连接差值状态缺少对应账本观测。");
        }
    }

    public void ResetBaseline()
    {
        _deltaTracker.Reset();
        _rateAggregator.Reset();
        _lastSnapshotTimestamp = null;
    }
}
