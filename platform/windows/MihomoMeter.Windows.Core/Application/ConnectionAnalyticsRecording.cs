using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public interface IConnectionAnalyticsRecorder
{
    Task RecordAsync(
        IReadOnlyList<ConnectionAttributionDelta> deltas,
        DateTimeOffset observedAt,
        CancellationToken cancellationToken);

    Task FlushPendingAsync(CancellationToken cancellationToken);
}

public interface IConnectionAnalyticsHistoryClearing
{
    Task<bool> ClearHistoryAsync(CancellationToken cancellationToken);
}

public interface IProxyDailyTrafficProvider
{
    Task<TrafficBytes> ProxyTrafficAsync(
        string localDay,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);
}

public interface IConnectionAnalyticsLedger : IAsyncDisposable
{
    Task<ConnectionAnalyticsLedgerSnapshot> PrepareAsync(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<ConnectionAnalyticsLedgerSnapshot> SetHistoryEnabledAsync(
        bool isEnabled,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<ConnectionAnalyticsLedgerSnapshot> RecordAsync(
        IReadOnlyList<ConnectionAttributionAggregate> aggregates,
        int maximumPairCountPerDay,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<ConnectionAttributionRecord>> RecordsAsync(
        string localDay,
        CancellationToken cancellationToken);

    Task<ConnectionAnalyticsTrend> TrendAsync(
        ConnectionAnalyticsTrendQuery query,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<ConnectionAnalyticsLedgerSnapshot> ClearHistoryAsync(
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken);
}

internal sealed class NullConnectionAnalyticsRecorder : IConnectionAnalyticsRecorder
{
    public static NullConnectionAnalyticsRecorder Instance { get; } = new();

    public Task RecordAsync(
        IReadOnlyList<ConnectionAttributionDelta> deltas,
        DateTimeOffset observedAt,
        CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }

    public Task FlushPendingAsync(CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }
}
