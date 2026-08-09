using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class WindowsUpdateCheckerTests
{
    [TestMethod]
    public async Task ReportsUpdateOnlyWhenWindowsActualVersionIsNewer()
    {
        var releaseUri = new Uri(
            "https://github.com/HongXunPan/mihomo-meter/releases/tag/v1.2.4");
        var checker = new WindowsUpdateChecker(
            new StubReleaseQuery(new WindowsReleaseSnapshot(
                new ReleaseVersion(1, 2, 4),
                releaseUri)));

        var available = await checker.CheckAsync(new ReleaseVersion(1, 2, 3));
        var same = await checker.CheckAsync(new ReleaseVersion(1, 2, 4));
        var newerLocal = await checker.CheckAsync(new ReleaseVersion(1, 3, 0));

        Assert.AreEqual(WindowsUpdateAvailability.UpdateAvailable, available.Availability);
        Assert.AreEqual(releaseUri, available.ReleasePageUri);
        Assert.AreEqual(WindowsUpdateAvailability.UpToDate, same.Availability);
        Assert.AreEqual(WindowsUpdateAvailability.UpToDate, newerLocal.Availability);
    }

    [TestMethod]
    public async Task ConvertsExpectedQueryFailureToIsolatedResult()
    {
        var checker = new WindowsUpdateChecker(new FailingReleaseQuery(
            WindowsReleaseQueryFailureCategory.RateLimited));

        var result = await checker.CheckAsync(new ReleaseVersion(1, 0, 0));

        Assert.AreEqual(WindowsUpdateAvailability.Failed, result.Availability);
        Assert.AreEqual(
            WindowsReleaseQueryFailureCategory.RateLimited,
            result.FailureCategory);
    }

    [TestMethod]
    public async Task ConcurrentChecksShareOneNetworkQuery()
    {
        var query = new DeferredReleaseQuery();
        var checker = new WindowsUpdateChecker(query);

        var first = checker.CheckAsync(new ReleaseVersion(1, 0, 0));
        var second = checker.CheckAsync(new ReleaseVersion(1, 0, 0));
        query.Complete(new WindowsReleaseSnapshot(
            new ReleaseVersion(1, 0, 1),
            new Uri("https://github.com/HongXunPan/mihomo-meter/releases/tag/v1.0.1")));

        await Task.WhenAll(first, second);
        Assert.AreSame(first, second);
        Assert.AreEqual(1, query.CallCount);
    }

    private sealed class StubReleaseQuery : IWindowsReleaseQuery
    {
        private readonly WindowsReleaseSnapshot _snapshot;

        public StubReleaseQuery(WindowsReleaseSnapshot snapshot)
        {
            _snapshot = snapshot;
        }

        public Task<WindowsReleaseSnapshot> GetLatestAsync(CancellationToken cancellationToken)
        {
            return Task.FromResult(_snapshot);
        }
    }

    private sealed class FailingReleaseQuery : IWindowsReleaseQuery
    {
        private readonly WindowsReleaseQueryFailureCategory _category;

        public FailingReleaseQuery(WindowsReleaseQueryFailureCategory category)
        {
            _category = category;
        }

        public Task<WindowsReleaseSnapshot> GetLatestAsync(CancellationToken cancellationToken)
        {
            throw new WindowsReleaseQueryException(_category, "测试失败");
        }
    }

    private sealed class DeferredReleaseQuery : IWindowsReleaseQuery
    {
        private readonly TaskCompletionSource<WindowsReleaseSnapshot> _completion = new(
            TaskCreationOptions.RunContinuationsAsynchronously);

        public int CallCount { get; private set; }

        public Task<WindowsReleaseSnapshot> GetLatestAsync(CancellationToken cancellationToken)
        {
            CallCount++;
            return _completion.Task;
        }

        public void Complete(WindowsReleaseSnapshot snapshot)
        {
            _completion.TrySetResult(snapshot);
        }
    }
}
