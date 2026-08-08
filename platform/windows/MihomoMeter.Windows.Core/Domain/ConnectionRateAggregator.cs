namespace MihomoMeter.Windows.Core.Domain;

public sealed class ConnectionRateAggregator
{
    private readonly double _windowDuration;
    private readonly int _smoothingWindowCount;
    private readonly Dictionary<string, TrafficBytes> _accumulatedBytesById =
        new(StringComparer.Ordinal);
    private readonly Dictionary<string, Queue<TrafficRate>> _recentRatesById =
        new(StringComparer.Ordinal);
    private readonly Dictionary<string, TrafficRate> _rateById =
        new(StringComparer.Ordinal);
    private Dictionary<string, ConnectionTrafficSample> _activeById =
        new(StringComparer.Ordinal);
    private double _accumulatedDuration;

    public ConnectionRateAggregator(
        double windowDuration = 1,
        int smoothingWindowCount = 2)
    {
        if (!double.IsFinite(windowDuration) || windowDuration <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(windowDuration));
        }

        if (smoothingWindowCount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(smoothingWindowCount));
        }

        _windowDuration = windowDuration;
        _smoothingWindowCount = smoothingWindowCount;
    }

    public IReadOnlyList<LiveTrafficConnection> LiveConnections => _activeById.Values
        .Select(connection => new LiveTrafficConnection(
            connection.Id,
            connection.Metadata,
            _rateById.GetValueOrDefault(connection.Id),
            connection.Bytes,
            connection.StartedAt))
        .ToArray();

    public void EstablishBaseline(IReadOnlyList<ConnectionTrafficSample> connections)
    {
        Reset();
        _activeById = KeyedById(connections);
    }

    public IReadOnlyList<LiveTrafficConnection> Consume(
        IReadOnlyList<ConnectionTrafficSample> activeConnections,
        IReadOnlyList<ConnectionTrafficDelta> deltas,
        double? elapsedSeconds)
    {
        var activeIds = activeConnections
            .Select(connection => connection.Id)
            .ToHashSet(StringComparer.Ordinal);
        RemoveInactiveConnections(activeIds);
        _activeById = KeyedById(activeConnections);

        if (elapsedSeconds is not double duration
            || !double.IsFinite(duration)
            || duration <= 0)
        {
            return LiveConnections;
        }

        _accumulatedDuration += duration;
        foreach (var delta in deltas.Where(delta => activeIds.Contains(delta.Id)))
        {
            _accumulatedBytesById[delta.Id] = TrafficBytes.Add(
                _accumulatedBytesById.GetValueOrDefault(delta.Id),
                delta.Bytes);
        }

        if (_accumulatedDuration < _windowDuration)
        {
            return LiveConnections;
        }

        foreach (var connection in activeConnections)
        {
            var bytes = _accumulatedBytesById.GetValueOrDefault(connection.Id);
            var rawRate = new TrafficRate(
                BytesPerSecond(bytes.Upload, _accumulatedDuration),
                BytesPerSecond(bytes.Download, _accumulatedDuration));
            var rates = _recentRatesById.GetValueOrDefault(connection.Id);
            if (rates is null)
            {
                rates = new Queue<TrafficRate>();
                _recentRatesById.Add(connection.Id, rates);
            }

            rates.Enqueue(rawRate);
            while (rates.Count > _smoothingWindowCount)
            {
                _ = rates.Dequeue();
            }

            _rateById[connection.Id] = Average(rates);
        }

        _accumulatedDuration = 0;
        _accumulatedBytesById.Clear();
        return LiveConnections;
    }

    public void Reset()
    {
        _accumulatedDuration = 0;
        _accumulatedBytesById.Clear();
        _recentRatesById.Clear();
        _rateById.Clear();
        _activeById.Clear();
    }

    private void RemoveInactiveConnections(IReadOnlySet<string> activeIds)
    {
        RemoveInactive(_accumulatedBytesById, activeIds);
        RemoveInactive(_recentRatesById, activeIds);
        RemoveInactive(_rateById, activeIds);
    }

    private static void RemoveInactive<T>(
        IDictionary<string, T> values,
        IReadOnlySet<string> activeIds)
    {
        foreach (var id in values.Keys.Where(id => !activeIds.Contains(id)).ToArray())
        {
            _ = values.Remove(id);
        }
    }

    private static Dictionary<string, ConnectionTrafficSample> KeyedById(
        IReadOnlyList<ConnectionTrafficSample> connections)
    {
        return connections.ToDictionary(
            connection => connection.Id,
            connection => connection,
            StringComparer.Ordinal);
    }

    private static ulong BytesPerSecond(ulong bytes, double duration)
    {
        var value = bytes / duration;
        return value >= ulong.MaxValue ? ulong.MaxValue : (ulong)value;
    }

    private static TrafficRate Average(IReadOnlyCollection<TrafficRate> rates)
    {
        if (rates.Count == 0)
        {
            return TrafficRate.Zero;
        }

        var totals = rates.Aggregate(
            TrafficBytes.Zero,
            (current, rate) => TrafficBytes.Add(
                current,
                new TrafficBytes(
                    rate.UploadBytesPerSecond,
                    rate.DownloadBytesPerSecond)));
        var count = (ulong)rates.Count;
        return new TrafficRate(totals.Upload / count, totals.Download / count);
    }
}
