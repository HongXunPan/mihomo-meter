namespace MihomoMeter.Windows.Core.Domain;

public readonly record struct ConnectionMetadataAvailability(
    bool HasHostname,
    bool HasApplication)
{
    public static ConnectionMetadataAvailability Unavailable => default;
}

public readonly record struct ConnectionAttributionCoverage(
    int ProxyConnectionCount,
    int HostnameIdentifiedCount,
    int ApplicationIdentifiedCount,
    int FullyIdentifiedCount)
{
    public static ConnectionAttributionCoverage Empty => default;

    public double? HostnameRate => RateFor(HostnameIdentifiedCount);

    public double? ApplicationRate => RateFor(ApplicationIdentifiedCount);

    public double? FullyIdentifiedRate => RateFor(FullyIdentifiedCount);

    private double? RateFor(int count)
    {
        return ProxyConnectionCount == 0
            ? null
            : (double)count / ProxyConnectionCount;
    }
}

public sealed class ConnectionAttributionCoverageTracker
{
    private readonly Dictionary<string, ConnectionMetadataAvailability> _availabilityByConnectionId =
        new(StringComparer.Ordinal);

    public ConnectionAttributionCoverage Consume(
        IReadOnlyList<ConnectionTrafficSample> proxyConnections)
    {
        foreach (var connection in proxyConnections)
        {
            _availabilityByConnectionId.TryGetValue(
                connection.Id,
                out var previousAvailability);
            _availabilityByConnectionId[connection.Id] = new ConnectionMetadataAvailability(
                previousAvailability.HasHostname || connection.MetadataAvailability.HasHostname,
                previousAvailability.HasApplication || connection.MetadataAvailability.HasApplication);
        }

        return Coverage;
    }

    public void Reset()
    {
        _availabilityByConnectionId.Clear();
    }

    private ConnectionAttributionCoverage Coverage
    {
        get
        {
            var values = _availabilityByConnectionId.Values;
            return new ConnectionAttributionCoverage(
                values.Count,
                values.Count(value => value.HasHostname),
                values.Count(value => value.HasApplication),
                values.Count(value => value.HasHostname && value.HasApplication));
        }
    }
}
