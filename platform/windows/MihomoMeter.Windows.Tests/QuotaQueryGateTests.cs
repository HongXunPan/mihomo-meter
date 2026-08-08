using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class QuotaQueryGateTests
{
    [TestMethod]
    public async Task SerializesConcurrentQueries()
    {
        using var gate = new QuotaQueryGate();
        var active = 0;
        var maximum = 0;
        var release = new TaskCompletionSource<bool>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        var firstStarted = new TaskCompletionSource<bool>(
            TaskCreationOptions.RunContinuationsAsynchronously);

        Task Operation(bool isFirst)
        {
            return gate.RunAsync(async () =>
            {
                var current = Interlocked.Increment(ref active);
                maximum = Math.Max(maximum, current);
                if (isFirst)
                {
                    firstStarted.TrySetResult(true);
                    await release.Task;
                }

                Interlocked.Decrement(ref active);
            }, CancellationToken.None);
        }

        var first = Operation(true);
        await firstStarted.Task.WaitAsync(TimeSpan.FromSeconds(2));
        var second = Operation(false);
        await Task.Delay(50);
        Assert.IsFalse(second.IsCompleted);

        release.TrySetResult(true);
        await Task.WhenAll(first, second).WaitAsync(TimeSpan.FromSeconds(2));

        Assert.AreEqual(1, maximum);
    }
}
