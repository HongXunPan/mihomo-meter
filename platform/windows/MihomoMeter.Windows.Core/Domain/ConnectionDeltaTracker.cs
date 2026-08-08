namespace MihomoMeter.Windows.Core.Domain;

public sealed class ConnectionDeltaTracker
{
    private TrafficBytes? _previousKernelTotal;
    private Dictionary<string, TrafficBytes> _previousConnections = new(StringComparer.Ordinal);

    public ConnectionDeltaResult Consume(
        ConnectionTrafficSnapshot snapshot,
        ProxyClassifier classifier)
    {
        if (_previousKernelTotal is null)
        {
            EstablishBaseline(snapshot);
            return new ConnectionDeltaResult(ConnectionDeltaStatus.BaselineEstablished);
        }

        var kernelDelta = TrafficBytes.NonnegativeDelta(
            snapshot.KernelTotal,
            _previousKernelTotal.Value);
        if (kernelDelta is null)
        {
            EstablishBaseline(snapshot);
            return new ConnectionDeltaResult(ConnectionDeltaStatus.CountersReset);
        }

        var categories = CategorizedTrafficBytes.Zero;
        var connectionDeltas = new List<ConnectionTrafficDelta>();

        foreach (var connection in snapshot.Connections)
        {
            TrafficBytes? delta = _previousConnections.TryGetValue(connection.Id, out var previous)
                ? TrafficBytes.NonnegativeDelta(connection.Bytes, previous)
                : connection.Bytes;
            if (delta is null)
            {
                continue;
            }

            var classification = classifier.Classify(connection.Chains);
            if (classification.Category == TrafficCategory.Unknown)
            {
                continue;
            }

            categories = categories.Adding(delta.Value, classification.Category);
            connectionDeltas.Add(new ConnectionTrafficDelta(
                connection.Id,
                classification.Category,
                delta.Value,
                connection.Bytes,
                connection.Metadata,
                connection.StartedAt));
        }

        var unknown = TrafficBytes.Residual(kernelDelta.Value, categories.Classified);
        categories = categories.Adding(unknown, TrafficCategory.Unknown);
        EstablishBaseline(snapshot);

        return new ConnectionDeltaResult(
            ConnectionDeltaStatus.Delta,
            new ConnectionDeltaBatch(
                new TrafficDeltaReport(kernelDelta.Value, categories),
                connectionDeltas));
    }

    public void Reset()
    {
        _previousKernelTotal = null;
        _previousConnections.Clear();
    }

    private void EstablishBaseline(ConnectionTrafficSnapshot snapshot)
    {
        _previousKernelTotal = snapshot.KernelTotal;
        _previousConnections = snapshot.Connections.ToDictionary(
            connection => connection.Id,
            connection => connection.Bytes,
            StringComparer.Ordinal);
    }
}
