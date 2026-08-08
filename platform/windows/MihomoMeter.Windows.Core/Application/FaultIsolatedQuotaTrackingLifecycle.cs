using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

internal sealed class FaultIsolatedQuotaTrackingLifecycle : IQuotaTrackingLifecycle
{
    private readonly IQuotaTrackingLifecycle _inner;

    public FaultIsolatedQuotaTrackingLifecycle(IQuotaTrackingLifecycle inner)
    {
        _inner = inner;
    }

    public Task ControllerValidatedAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken)
    {
        return IgnoreFailureAsync(() => _inner.ControllerValidatedAsync(
            endpoint,
            secret,
            cancellationToken));
    }

    public Task ControllerUnavailableAsync(CancellationToken cancellationToken)
    {
        return IgnoreFailureAsync(() => _inner.ControllerUnavailableAsync(cancellationToken));
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
