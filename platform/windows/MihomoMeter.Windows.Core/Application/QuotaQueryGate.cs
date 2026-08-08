namespace MihomoMeter.Windows.Core.Application;

internal sealed class QuotaQueryGate : IDisposable
{
    private readonly SemaphoreSlim _semaphore = new(1, 1);

    public async Task RunAsync(Func<Task> operation, CancellationToken cancellationToken)
    {
        await _semaphore.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await operation().ConfigureAwait(false);
        }
        finally
        {
            _semaphore.Release();
        }
    }

    public void Dispose()
    {
        _semaphore.Dispose();
    }
}
