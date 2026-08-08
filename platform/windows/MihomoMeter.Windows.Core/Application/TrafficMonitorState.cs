using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public enum MonitorConnectionState
{
    Disconnected,
    Connecting,
    Connected,
    Stale,
    Reconnecting,
    AuthenticationFailed,
    Unsupported,
}

public sealed record TrafficMonitorSnapshot(
    MonitorConnectionState State,
    string Message,
    string? MihomoVersion = null,
    CategorizedTrafficRates? Rates = null,
    double? Coverage = null,
    long SessionGeneration = 0,
    ConnectionAttributionCoverage AttributionCoverage = default)
{
    public static TrafficMonitorSnapshot Disconnected => new(
        MonitorConnectionState.Disconnected,
        "尚未连接 Mihomo Controller。");
}

public sealed record MonitoringPolicy(
    TimeSpan StaleAfter,
    TimeSpan ReconnectAfter,
    TimeSpan BackoffResetAfter)
{
    public static MonitoringPolicy Production => new(
        TimeSpan.FromSeconds(2),
        TimeSpan.FromSeconds(5),
        TimeSpan.FromSeconds(30));

    public MonitoringPolicy Validate()
    {
        if (StaleAfter <= TimeSpan.Zero
            || ReconnectAfter <= StaleAfter
            || BackoffResetAfter <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(MonitoringPolicy));
        }

        return this;
    }
}
