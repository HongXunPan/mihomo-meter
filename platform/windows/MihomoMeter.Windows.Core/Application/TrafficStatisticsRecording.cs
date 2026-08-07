using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public interface ITrafficStatisticsRecorder
{
    Task BeginMonitoringAsync(string version, CancellationToken cancellationToken);

    Task RecordAsync(
        TrafficLedgerObservation observation,
        CancellationToken cancellationToken);

    Task InterruptMonitoringAsync(
        TrafficSessionEndReason reason,
        CancellationToken cancellationToken);
}

public interface ITrafficLedger : IAsyncDisposable
{
    Task<TrafficStatisticsSnapshot> PrepareAsync(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<TrafficStatisticsSnapshot> BeginMonitoringAsync(
        string version,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<TrafficStatisticsSnapshot> RecordAsync(
        TrafficLedgerObservation observation,
        TimeZoneInfo timeZone,
        CancellationToken cancellationToken);

    Task<TrafficStatisticsSnapshot> InterruptMonitoringAsync(
        TrafficSessionEndReason reason,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<TrafficStatisticsSnapshot> StartIntervalAsync(
        string name,
        string? note,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<TrafficStatisticsSnapshot> StopIntervalAsync(
        Guid id,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<TrafficStatisticsSnapshot> RenameIntervalAsync(
        Guid id,
        string name,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<TrafficStatisticsSnapshot> DeleteIntervalAsync(
        Guid id,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<TrafficStatisticsSnapshot> InterruptActiveIntervalsAsync(
        TrafficIntervalEndReason reason,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<TrafficStatisticsSnapshot> ClearAsync(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);
}

internal sealed class NullTrafficStatisticsRecorder : ITrafficStatisticsRecorder
{
    public static NullTrafficStatisticsRecorder Instance { get; } = new();

    public Task BeginMonitoringAsync(string version, CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }

    public Task RecordAsync(
        TrafficLedgerObservation observation,
        CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }

    public Task InterruptMonitoringAsync(
        TrafficSessionEndReason reason,
        CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }
}
