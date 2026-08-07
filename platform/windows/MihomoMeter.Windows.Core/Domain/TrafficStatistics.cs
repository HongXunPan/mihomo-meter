namespace MihomoMeter.Windows.Core.Domain;

public sealed record TrafficStatisticsSnapshot(
    CategorizedTrafficBytes Today,
    CategorizedTrafficBytes Lifetime,
    DateTimeOffset? LastObservedAt)
{
    public static TrafficStatisticsSnapshot Empty => new(
        CategorizedTrafficBytes.Zero,
        CategorizedTrafficBytes.Zero,
        null);
}

public enum TrafficStatisticsAvailability
{
    Loading,
    Available,
    Unavailable,
}

public sealed record TrafficStatisticsState(
    TrafficStatisticsAvailability Availability,
    TrafficStatisticsSnapshot Snapshot,
    string? Message = null)
{
    public static TrafficStatisticsState Loading => new(
        TrafficStatisticsAvailability.Loading,
        TrafficStatisticsSnapshot.Empty);
}

public enum TrafficSessionEndReason
{
    MonitoringStopped,
    ApplicationExit,
    TerminalFailure,
    Recovery,
}
