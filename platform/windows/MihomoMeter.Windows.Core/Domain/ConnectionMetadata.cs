namespace MihomoMeter.Windows.Core.Domain;

public readonly record struct ConnectionMetadata(
    string? Hostname,
    string? ApplicationName)
{
    public static ConnectionMetadata Unavailable => default;

    public ConnectionMetadataAvailability Availability => new(
        Hostname is not null,
        ApplicationName is not null);
}

public static class ConnectionAttributionLabel
{
    public const string UnknownApplication = "未知应用";
    public const string UnknownHostname = "未知域名";
}

public enum MihomoProcessMatchingMode
{
    Always,
    Strict,
    Off,
}
