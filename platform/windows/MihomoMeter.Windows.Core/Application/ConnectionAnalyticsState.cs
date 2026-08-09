using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public enum ConnectionAnalyticsAvailability
{
    Loading,
    Available,
    Unavailable,
}

public sealed record ConnectionAnalyticsState(
    ConnectionAnalyticsAvailability Availability,
    ConnectionAnalyticsLedgerSnapshot Snapshot,
    string? SelectedLocalDay,
    IReadOnlyList<ConnectionAttributionRecord> SelectedRecords,
    ConnectionAnalyticsRecordingCoverage? RecordingCoverage,
    string? Message = null)
{
    public static ConnectionAnalyticsState Loading => new(
        ConnectionAnalyticsAvailability.Loading,
        ConnectionAnalyticsLedgerSnapshot.Empty,
        null,
        Array.Empty<ConnectionAttributionRecord>(),
        null);
}
