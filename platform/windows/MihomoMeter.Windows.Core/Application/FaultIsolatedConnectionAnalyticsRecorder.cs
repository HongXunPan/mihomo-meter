using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

internal sealed class FaultIsolatedConnectionAnalyticsRecorder : IConnectionAnalyticsRecorder
{
    private readonly IConnectionAnalyticsRecorder _inner;

    public FaultIsolatedConnectionAnalyticsRecorder(IConnectionAnalyticsRecorder inner)
    {
        _inner = inner;
    }

    public Task RecordAsync(
        IReadOnlyList<ConnectionAttributionDelta> deltas,
        DateTimeOffset observedAt,
        CancellationToken cancellationToken)
    {
        return IgnoreFailureAsync(() => _inner.RecordAsync(
            deltas,
            observedAt,
            cancellationToken));
    }

    public Task FlushPendingAsync(CancellationToken cancellationToken)
    {
        return IgnoreFailureAsync(() => _inner.FlushPendingAsync(cancellationToken));
    }

    private static async Task IgnoreFailureAsync(Func<Task> operation)
    {
        try
        {
            await operation().ConfigureAwait(false);
        }
        catch (Exception)
        {
        }
    }
}
