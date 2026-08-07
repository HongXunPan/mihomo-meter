namespace MihomoMeter.Windows.Core.Domain;

public enum TrafficIntervalStatus
{
    Active,
    Completed,
    Interrupted,
}

public enum TrafficIntervalEndReason
{
    User,
    ApplicationExit,
    MonitoringStopped,
    Recovery,
    StatisticsUnavailable,
}

public sealed record TrafficInterval(
    Guid Id,
    string Name,
    string? Note,
    TrafficIntervalStatus Status,
    DateTimeOffset StartedAt,
    DateTimeOffset? EndedAt,
    TrafficIntervalEndReason? EndReason,
    TrafficBytes ProxyUsage);

public sealed record TrafficDailyTotal(string LocalDay, TrafficBytes Bytes);

public static class TrafficIntervalInput
{
    public static string NormalizeName(string name)
    {
        ArgumentNullException.ThrowIfNull(name);
        var normalized = name.Trim();
        if (normalized.Length == 0)
        {
            throw new ArgumentException("统计任务名称不能为空。", nameof(name));
        }

        return normalized;
    }

    public static string? NormalizeNote(string? note)
    {
        var normalized = note?.Trim();
        return string.IsNullOrEmpty(normalized) ? null : normalized;
    }
}

public sealed class TrafficIntervalOperationException : Exception
{
    public TrafficIntervalOperationException(string message)
        : base(message)
    {
    }
}
