using System.Globalization;

namespace MihomoMeter.Windows.Core.Domain;

public sealed record ConnectionAttributionDelta(
    ConnectionMetadata Metadata,
    TrafficBytes Bytes);

public readonly record struct ConnectionAttributionStorageKey(
    string LocalDay,
    string ApplicationName,
    string Hostname);

public sealed record ConnectionAttributionAggregate(
    ConnectionAttributionStorageKey Key,
    TrafficBytes Bytes);

public sealed record ConnectionAttributionRecord(
    string LocalDay,
    string ApplicationName,
    string Hostname,
    TrafficBytes Bytes);

public readonly record struct ConnectionAnalyticsCoverage(
    TrafficBytes Total,
    TrafficBytes HostnameAttributed,
    TrafficBytes ApplicationAttributed,
    TrafficBytes FullyAttributed)
{
    public static ConnectionAnalyticsCoverage Empty => new(
        TrafficBytes.Zero,
        TrafficBytes.Zero,
        TrafficBytes.Zero,
        TrafficBytes.Zero);

    public double? HostnameRate => Rate(HostnameAttributed);

    public double? ApplicationRate => Rate(ApplicationAttributed);

    public double? FullyAttributedRate => Rate(FullyAttributed);

    private double? Rate(TrafficBytes bytes)
    {
        return Total.Total == 0
            ? null
            : Math.Min((double)bytes.Total / Total.Total, 1);
    }
}

public readonly record struct ConnectionAnalyticsRecordingCoverage(
    TrafficBytes Attributed,
    TrafficBytes CoreProxy)
{
    public double? Rate => CoreProxy.Total == 0
        ? null
        : Math.Min((double)Attributed.Total / CoreProxy.Total, 1);
}

public sealed record ConnectionAnalyticsDay(
    string LocalDay,
    TrafficBytes Bytes,
    ConnectionAnalyticsCoverage Coverage);

public sealed record ConnectionAnalyticsLedgerSnapshot(
    bool IsHistoryEnabled,
    IReadOnlyList<ConnectionAnalyticsDay> RecentDays)
{
    public static ConnectionAnalyticsLedgerSnapshot Empty => new(
        false,
        Array.Empty<ConnectionAnalyticsDay>());
}

public sealed record ConnectionAnalyticsTrendQuery
{
    public ConnectionAnalyticsTrendQuery(
        string? applicationName = null,
        string? hostname = null)
    {
        if (string.IsNullOrWhiteSpace(applicationName)
            && string.IsNullOrWhiteSpace(hostname))
        {
            throw new ArgumentException("归因趋势至少需要一个精确维度。");
        }

        ApplicationName = Normalized(applicationName);
        Hostname = Normalized(hostname);
    }

    public string? ApplicationName { get; }

    public string? Hostname { get; }

    private static string? Normalized(string? value)
    {
        var normalized = value?.Trim();
        return string.IsNullOrEmpty(normalized) ? null : normalized;
    }
}

public sealed record ConnectionAnalyticsTrendPoint(
    string LocalDay,
    TrafficBytes Bytes);

public sealed record ConnectionAnalyticsTrend(
    IReadOnlyList<ConnectionAnalyticsTrendPoint> Points)
{
    public TrafficBytes TotalBytes => Points.Aggregate(
        TrafficBytes.Zero,
        (total, point) => TrafficBytes.Add(total, point.Bytes));

    public int ActiveDayCount => Points.Count(point => point.Bytes.Total > 0);

    public ulong ActiveDailyAverageBytes => ActiveDayCount == 0
        ? 0
        : TotalBytes.Total / (ulong)ActiveDayCount;

    public ConnectionAnalyticsTrendPoint? PeakPoint => Points
        .Where(point => point.Bytes.Total > 0)
        .Aggregate<ConnectionAnalyticsTrendPoint, ConnectionAnalyticsTrendPoint?>(
            null,
            (peak, point) => peak is null || point.Bytes.Total >= peak.Bytes.Total
                ? point
                : peak);

    public string? DefaultSelectedLocalDay => Points
        .LastOrDefault(point => point.Bytes.Total > 0)
        ?.LocalDay;
}

public static class ConnectionAnalyticsCalendar
{
    public const int RecentDayCount = 30;

    public static string LocalDay(DateTimeOffset date, TimeZoneInfo timeZone)
    {
        return TimeZoneInfo
            .ConvertTime(date, timeZone)
            .ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    }

    public static IReadOnlyList<string> RecentLocalDays(
        DateTimeOffset now,
        TimeZoneInfo timeZone)
    {
        var localToday = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(now, timeZone).Date);
        return Enumerable.Range(0, RecentDayCount)
            .Select(offset => localToday
                .AddDays(offset - RecentDayCount + 1)
                .ToString("yyyy-MM-dd", CultureInfo.InvariantCulture))
            .ToArray();
    }
}

public sealed class ConnectionAnalyticsException : Exception
{
    public ConnectionAnalyticsException(string message)
        : base(message)
    {
    }

    public ConnectionAnalyticsException(string message, Exception innerException)
        : base(message, innerException)
    {
    }
}
