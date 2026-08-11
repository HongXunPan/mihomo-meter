namespace MihomoMeter.Windows.Core.Domain;

public readonly record struct TrafficBytes(ulong Upload, ulong Download)
{
    public static TrafficBytes Zero => new(0, 0);

    public ulong Total => SaturatedAdd(Upload, Download);

    public static TrafficBytes Add(TrafficBytes left, TrafficBytes right)
    {
        return new TrafficBytes(
            SaturatedAdd(left.Upload, right.Upload),
            SaturatedAdd(left.Download, right.Download));
    }

    public static TrafficBytes? NonnegativeDelta(TrafficBytes current, TrafficBytes previous)
    {
        if (current.Upload < previous.Upload || current.Download < previous.Download)
        {
            return null;
        }

        return new TrafficBytes(
            current.Upload - previous.Upload,
            current.Download - previous.Download);
    }

    public static TrafficBytes Residual(TrafficBytes total, TrafficBytes value)
    {
        return new TrafficBytes(
            total.Upload >= value.Upload ? total.Upload - value.Upload : 0,
            total.Download >= value.Download ? total.Download - value.Download : 0);
    }

    private static ulong SaturatedAdd(ulong left, ulong right)
    {
        return ulong.MaxValue - left < right ? ulong.MaxValue : left + right;
    }
}

public enum TrafficCategory
{
    Proxy,
    Direct,
    Reject,
    Unknown,
}

public sealed record ConnectionTrafficSample(
    string Id,
    TrafficBytes Bytes,
    IReadOnlyList<string> Chains,
    ConnectionMetadata Metadata = default,
    DateTimeOffset? StartedAt = null,
    string? Rule = null)
{
    public ConnectionMetadataAvailability MetadataAvailability => Metadata.Availability;
}

public sealed record ConnectionTrafficSnapshot(
    TrafficBytes KernelTotal,
    IReadOnlyList<ConnectionTrafficSample> Connections);

public readonly record struct CategorizedTrafficBytes(
    TrafficBytes Proxy,
    TrafficBytes Direct,
    TrafficBytes Reject,
    TrafficBytes Unknown)
{
    public static CategorizedTrafficBytes Zero => new(
        TrafficBytes.Zero,
        TrafficBytes.Zero,
        TrafficBytes.Zero,
        TrafficBytes.Zero);

    public TrafficBytes Classified => TrafficBytes.Add(
        TrafficBytes.Add(Proxy, Direct),
        Reject);

    public CategorizedTrafficBytes Adding(TrafficBytes bytes, TrafficCategory category)
    {
        return category switch
        {
            TrafficCategory.Proxy => this with { Proxy = TrafficBytes.Add(Proxy, bytes) },
            TrafficCategory.Direct => this with { Direct = TrafficBytes.Add(Direct, bytes) },
            TrafficCategory.Reject => this with { Reject = TrafficBytes.Add(Reject, bytes) },
            TrafficCategory.Unknown => this with { Unknown = TrafficBytes.Add(Unknown, bytes) },
            _ => this,
        };
    }
}

public sealed record TrafficDeltaReport(
    TrafficBytes Kernel,
    CategorizedTrafficBytes Categories)
{
    public double Coverage => Kernel.Total == 0
        ? 1
        : Math.Min((double)Categories.Classified.Total / Kernel.Total, 1);
}

public sealed record ConnectionTrafficDelta(
    string Id,
    TrafficCategory Category,
    TrafficBytes Bytes,
    TrafficBytes CumulativeBytes,
    ConnectionMetadata Metadata,
    DateTimeOffset? StartedAt);

public sealed record ConnectionDeltaBatch(
    TrafficDeltaReport Traffic,
    IReadOnlyList<ConnectionTrafficDelta> Connections);

public enum ConnectionDeltaStatus
{
    BaselineEstablished,
    Delta,
    CountersReset,
}

public sealed record ConnectionDeltaResult(
    ConnectionDeltaStatus Status,
    ConnectionDeltaBatch? Batch = null);

public readonly record struct TrafficRate(
    ulong UploadBytesPerSecond,
    ulong DownloadBytesPerSecond)
{
    public static TrafficRate Zero => new(0, 0);
}

public sealed record LiveTrafficConnection(
    string Id,
    ConnectionMetadata Metadata,
    TrafficRate Rate,
    TrafficBytes CumulativeBytes,
    DateTimeOffset? StartedAt)
{
    public ulong TotalBytesPerSecond => new TrafficBytes(
        Rate.UploadBytesPerSecond,
        Rate.DownloadBytesPerSecond).Total;
}

public readonly record struct CategorizedTrafficRates(
    TrafficRate Proxy,
    TrafficRate Direct,
    TrafficRate Reject,
    TrafficRate Unknown)
{
    public static CategorizedTrafficRates Zero => new(
        TrafficRate.Zero,
        TrafficRate.Zero,
        TrafficRate.Zero,
        TrafficRate.Zero);
}

public sealed record TrafficRateWindow(
    CategorizedTrafficRates Raw,
    CategorizedTrafficRates Smoothed,
    double Coverage);
