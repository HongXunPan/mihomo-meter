using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public enum LiveConnectionRoute
{
    Proxy,
    Direct,
}

public enum LiveConnectionViewMode
{
    Connection,
    Application,
    Hostname,
}

public sealed record LiveConnectionGroupRow(
    LiveConnectionViewMode Mode,
    string Name,
    int RelatedCount,
    int ConnectionCount,
    TrafficRate Rate,
    TrafficBytes CumulativeBytes)
{
    public string Id => $"{Mode}:{Name}";

    public ulong TotalBytesPerSecond => AddRate(Rate).Total;

    private static TrafficBytes AddRate(TrafficRate rate)
    {
        return new TrafficBytes(
            rate.UploadBytesPerSecond,
            rate.DownloadBytesPerSecond);
    }
}

public static class LiveConnectionProjection
{
    public const int TopSlotCount = 5;

    public static IReadOnlyList<LiveTrafficConnection> SourceConnections(
        LiveConnectionRoute route,
        IReadOnlyList<LiveTrafficConnection> proxyConnections,
        IReadOnlyList<LiveTrafficConnection> directConnections)
    {
        return route == LiveConnectionRoute.Proxy
            ? proxyConnections
            : directConnections;
    }

    public static IReadOnlyList<LiveTrafficConnection> Connections(
        IReadOnlyList<LiveTrafficConnection> connections,
        string searchText)
    {
        return Filtered(connections, searchText)
            .OrderByDescending(connection => connection.TotalBytesPerSecond)
            .ThenBy(Hostname, StringComparer.Ordinal)
            .ThenBy(connection => connection.Id, StringComparer.Ordinal)
            .ToArray();
    }

    public static IReadOnlyList<LiveConnectionGroupRow> Groups(
        IReadOnlyList<LiveTrafficConnection> connections,
        LiveConnectionViewMode mode,
        string searchText)
    {
        if (mode == LiveConnectionViewMode.Connection)
        {
            return Array.Empty<LiveConnectionGroupRow>();
        }

        var accumulators = new Dictionary<string, GroupAccumulator>(StringComparer.Ordinal);
        foreach (var connection in Filtered(connections, searchText))
        {
            var name = mode == LiveConnectionViewMode.Application
                ? ApplicationName(connection)
                : Hostname(connection);
            var relatedName = mode == LiveConnectionViewMode.Application
                ? Hostname(connection)
                : ApplicationName(connection);
            if (!accumulators.TryGetValue(name, out var accumulator))
            {
                accumulator = new GroupAccumulator();
                accumulators.Add(name, accumulator);
            }

            _ = accumulator.RelatedNames.Add(relatedName);
            accumulator.ConnectionCount += 1;
            accumulator.Rate = Add(accumulator.Rate, connection.Rate);
            accumulator.CumulativeBytes = TrafficBytes.Add(
                accumulator.CumulativeBytes,
                connection.CumulativeBytes);
        }

        return accumulators.Select(item => new LiveConnectionGroupRow(
                mode,
                item.Key,
                item.Value.RelatedNames.Count,
                item.Value.ConnectionCount,
                item.Value.Rate,
                item.Value.CumulativeBytes))
            .OrderByDescending(row => row.TotalBytesPerSecond)
            .ThenBy(row => row.Name, StringComparer.Ordinal)
            .ToArray();
    }

    public static IReadOnlyList<LiveTrafficConnection?> TopSlots(
        IReadOnlyList<LiveTrafficConnection> connections)
    {
        var top = connections
            .Where(connection => connection.TotalBytesPerSecond > 0)
            .OrderByDescending(connection => connection.TotalBytesPerSecond)
            .ThenBy(Hostname, StringComparer.Ordinal)
            .Take(TopSlotCount)
            .ToArray();
        return Enumerable.Range(0, TopSlotCount)
            .Select(index => index < top.Length ? top[index] : null)
            .ToArray();
    }

    public static string ApplicationName(LiveTrafficConnection connection)
    {
        return connection.Metadata.ApplicationName
            ?? ConnectionAttributionLabel.UnknownApplication;
    }

    public static string Hostname(LiveTrafficConnection connection)
    {
        return connection.Metadata.Hostname
            ?? ConnectionAttributionLabel.UnknownHostname;
    }

    private static IEnumerable<LiveTrafficConnection> Filtered(
        IReadOnlyList<LiveTrafficConnection> connections,
        string searchText)
    {
        var query = searchText.Trim();
        return query.Length == 0
            ? connections
            : connections.Where(connection =>
                ApplicationName(connection).Contains(query, StringComparison.OrdinalIgnoreCase)
                || Hostname(connection).Contains(query, StringComparison.OrdinalIgnoreCase));
    }

    private static TrafficRate Add(TrafficRate left, TrafficRate right)
    {
        var totals = TrafficBytes.Add(
            new TrafficBytes(left.UploadBytesPerSecond, left.DownloadBytesPerSecond),
            new TrafficBytes(right.UploadBytesPerSecond, right.DownloadBytesPerSecond));
        return new TrafficRate(totals.Upload, totals.Download);
    }

    private sealed class GroupAccumulator
    {
        public HashSet<string> RelatedNames { get; } = new(StringComparer.Ordinal);

        public int ConnectionCount { get; set; }

        public TrafficRate Rate { get; set; } = TrafficRate.Zero;

        public TrafficBytes CumulativeBytes { get; set; } = TrafficBytes.Zero;
    }
}

public sealed record ApplicationIdentificationDiagnostic(
    string Title,
    string Detail,
    bool IsWarning,
    bool ShouldShowDetail)
{
    public static ApplicationIdentificationDiagnostic Create(
        MihomoProcessMatchingMode? mode,
        ConnectionAttributionCoverage coverage)
    {
        var count = $"{coverage.ApplicationIdentifiedCount}/{coverage.ProxyConnectionCount}";
        return mode switch
        {
            MihomoProcessMatchingMode.Always => new(
                $"进程识别 always · {count}",
                "Mihomo 会为所有连接查找进程；系统权限和连接类型仍可能影响结果。",
                false,
                false),
            MihomoProcessMatchingMode.Strict => new(
                $"进程识别 strict · {count}",
                "Mihomo 仅在来源可确认时匹配进程，部分连接可能无法识别。",
                false,
                false),
            MihomoProcessMatchingMode.Off => new(
                $"进程识别 off · {count}",
                "Mihomo 已关闭进程匹配，应用识别率可能较低。",
                true,
                true),
            _ => new(
                $"进程识别不可确认 · {count}",
                "Mihomo 未返回可识别的进程匹配模式。",
                false,
                true),
        };
    }
}
