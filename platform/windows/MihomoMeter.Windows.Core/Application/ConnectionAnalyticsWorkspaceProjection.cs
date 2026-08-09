using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public sealed record ConnectionAnalyticsRankingItem(
    string Name,
    TrafficBytes Bytes);

public static class ConnectionAnalyticsWorkspaceProjection
{
    public static IReadOnlyList<string> ApplicationNames(
        IReadOnlyList<ConnectionAttributionRecord> records)
    {
        return records
            .Select(record => record.ApplicationName)
            .Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal)
            .ToArray();
    }

    public static IReadOnlyList<string> Hostnames(
        IReadOnlyList<ConnectionAttributionRecord> records)
    {
        return records
            .Select(record => record.Hostname)
            .Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal)
            .ToArray();
    }

    public static IReadOnlyList<ConnectionAnalyticsRankingItem> ApplicationRanking(
        IReadOnlyList<ConnectionAttributionRecord> records,
        string? applicationName,
        string? hostname)
    {
        return Ranking(
            Filtered(records, applicationName, hostname),
            record => record.ApplicationName);
    }

    public static IReadOnlyList<ConnectionAnalyticsRankingItem> HostnameRanking(
        IReadOnlyList<ConnectionAttributionRecord> records,
        string? applicationName,
        string? hostname)
    {
        return Ranking(
            Filtered(records, applicationName, hostname),
            record => record.Hostname);
    }

    private static IEnumerable<ConnectionAttributionRecord> Filtered(
        IReadOnlyList<ConnectionAttributionRecord> records,
        string? applicationName,
        string? hostname)
    {
        return records.Where(record =>
            (applicationName is null
                || string.Equals(
                    record.ApplicationName,
                    applicationName,
                    StringComparison.Ordinal))
            && (hostname is null
                || string.Equals(record.Hostname, hostname, StringComparison.Ordinal)));
    }

    private static IReadOnlyList<ConnectionAnalyticsRankingItem> Ranking(
        IEnumerable<ConnectionAttributionRecord> records,
        Func<ConnectionAttributionRecord, string> name)
    {
        var bytesByName = new Dictionary<string, TrafficBytes>(StringComparer.Ordinal);
        foreach (var record in records)
        {
            var key = name(record);
            bytesByName[key] = TrafficBytes.Add(
                bytesByName.GetValueOrDefault(key, TrafficBytes.Zero),
                record.Bytes);
        }
        return bytesByName
            .Select(item => new ConnectionAnalyticsRankingItem(item.Key, item.Value))
            .OrderByDescending(item => item.Bytes.Total)
            .ThenBy(item => item.Name, StringComparer.Ordinal)
            .ToArray();
    }
}
