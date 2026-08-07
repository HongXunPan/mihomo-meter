using System.Runtime.CompilerServices;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class TrafficMonitoringCoordinatorTests
{
    [TestMethod]
    public async Task SavesConfigurationOnlyAfterHttpValidationCompletes()
    {
        var sequence = new List<string>();
        var client = new TestControllerClient(sequence);
        var collector = new TestSnapshotCollector(sequence);
        var store = new TestConfigurationStore(sequence);
        await using var coordinator = new TrafficMonitoringCoordinator(
            client,
            collector,
            store);

        await coordinator.StartAsync(
            "127.0.0.1:9090",
            "synthetic-secret",
            true);
        await collector.Started.Task.WaitAsync(TimeSpan.FromSeconds(2));

        CollectionAssert.AreEqual(
            new[] { "version", "proxies", "save", "stream" },
            sequence);
        Assert.AreEqual("http://127.0.0.1:9090", store.SavedAddress);
        Assert.AreEqual("synthetic-secret", store.SavedSecret);
    }

    [TestMethod]
    public async Task AuthenticationFailureIsTerminalAndDoesNotSaveConfiguration()
    {
        var sequence = new List<string>();
        var client = new TestControllerClient(sequence)
        {
            VersionFailure = new MihomoControllerException(
                MihomoControllerError.AuthenticationFailed),
        };
        var store = new TestConfigurationStore(sequence);
        var terminalSnapshot = new TaskCompletionSource<TrafficMonitorSnapshot>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        await using var coordinator = new TrafficMonitoringCoordinator(
            client,
            new TestSnapshotCollector(sequence),
            store);
        coordinator.SnapshotChanged += snapshot =>
        {
            if (snapshot.State == MonitorConnectionState.AuthenticationFailed)
            {
                terminalSnapshot.TrySetResult(snapshot);
            }
        };

        await coordinator.StartAsync(
            "127.0.0.1:9090",
            "invalid-synthetic-secret",
            true);
        var snapshot = await terminalSnapshot.Task.WaitAsync(TimeSpan.FromSeconds(2));

        Assert.AreEqual(MonitorConnectionState.AuthenticationFailed, snapshot.State);
        Assert.AreEqual(0, store.SaveCount);
        CollectionAssert.AreEqual(new[] { "version" }, sequence);
    }

    [TestMethod]
    public async Task StaleStreamTransitionsToReconnectAfterPolicyTimeout()
    {
        var sequence = new List<string>();
        var staleSnapshot = new TaskCompletionSource<TrafficMonitorSnapshot>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        var reconnectSnapshot = new TaskCompletionSource<TrafficMonitorSnapshot>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        await using var coordinator = new TrafficMonitoringCoordinator(
            new TestControllerClient(sequence),
            new StalledSnapshotCollector(),
            new TestConfigurationStore(sequence),
            new MonitoringPolicy(
                TimeSpan.FromMilliseconds(100),
                TimeSpan.FromMilliseconds(300),
                TimeSpan.FromMilliseconds(500)));
        coordinator.SnapshotChanged += snapshot =>
        {
            if (snapshot.State == MonitorConnectionState.Stale)
            {
                staleSnapshot.TrySetResult(snapshot);
            }

            if (snapshot.State == MonitorConnectionState.Reconnecting)
            {
                reconnectSnapshot.TrySetResult(snapshot);
            }
        };

        await coordinator.StartAsync("127.0.0.1:9090", string.Empty, false);
        var stale = await staleSnapshot.Task.WaitAsync(TimeSpan.FromSeconds(2));
        var reconnect = await reconnectSnapshot.Task.WaitAsync(TimeSpan.FromSeconds(2));

        Assert.AreEqual(MonitorConnectionState.Stale, stale.State);
        Assert.IsNull(stale.Rates);
        Assert.AreEqual(MonitorConnectionState.Reconnecting, reconnect.State);
    }

    [TestMethod]
    public async Task StartingNewSessionCancelsPreviousStreamBeforeReplacement()
    {
        var sequence = new List<string>();
        var collector = new SessionTrackingCollector();
        var firstConnected = new TaskCompletionSource<long>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        var secondConnected = new TaskCompletionSource<long>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        var connectedCount = 0;
        await using var coordinator = new TrafficMonitoringCoordinator(
            new TestControllerClient(sequence),
            collector,
            new TestConfigurationStore(sequence));
        coordinator.SnapshotChanged += snapshot =>
        {
            if (snapshot.State != MonitorConnectionState.Connected)
            {
                return;
            }

            if (Interlocked.Increment(ref connectedCount) == 1)
            {
                firstConnected.TrySetResult(snapshot.SessionGeneration);
            }
            else
            {
                secondConnected.TrySetResult(snapshot.SessionGeneration);
            }
        };

        await coordinator.StartAsync("127.0.0.1:9090", string.Empty, false);
        Assert.IsTrue(await collector.Started.WaitAsync(TimeSpan.FromSeconds(2)));
        var firstGeneration = await firstConnected.Task.WaitAsync(TimeSpan.FromSeconds(2));

        var replacementTask = coordinator.StartAsync(
            "127.0.0.1:9090",
            string.Empty,
            false);
        await collector.FirstCleanupStarted.Task.WaitAsync(TimeSpan.FromSeconds(2));
        try
        {
            Assert.IsFalse(replacementTask.IsCompleted);
            Assert.AreEqual(1, collector.RunCount);
            Assert.AreEqual(1, collector.MaximumConcurrentRuns);
        }
        finally
        {
            collector.ReleaseFirstCleanup();
        }

        await replacementTask.WaitAsync(TimeSpan.FromSeconds(2));
        Assert.IsTrue(await collector.Started.WaitAsync(TimeSpan.FromSeconds(2)));
        var secondGeneration = await secondConnected.Task.WaitAsync(TimeSpan.FromSeconds(2));

        Assert.AreEqual(2, collector.RunCount);
        Assert.AreEqual(1, collector.MaximumConcurrentRuns);
        Assert.IsFalse(coordinator.IsCurrentSession(firstGeneration));
        Assert.IsTrue(coordinator.IsCurrentSession(secondGeneration));
    }

    private sealed class TestControllerClient : IMihomoControllerClient
    {
        private readonly List<string> _sequence;

        public TestControllerClient(List<string> sequence)
        {
            _sequence = sequence;
        }

        public Exception? VersionFailure { get; init; }

        public Task<MihomoVersionResponse> FetchVersionAsync(
            ControllerEndpoint endpoint,
            string secret,
            CancellationToken cancellationToken)
        {
            _sequence.Add("version");
            return VersionFailure is null
                ? Task.FromResult(new MihomoVersionResponse
                {
                    Meta = true,
                    Version = "v1.19.0",
                })
                : Task.FromException<MihomoVersionResponse>(VersionFailure);
        }

        public Task<MihomoProxiesResponse> FetchProxiesAsync(
            ControllerEndpoint endpoint,
            string secret,
            CancellationToken cancellationToken)
        {
            _sequence.Add("proxies");
            return Task.FromResult(new MihomoProxiesResponse
            {
                Proxies = new Dictionary<string, MihomoProxyResponse>
                {
                    ["DIRECT"] = new MihomoProxyResponse
                    {
                        Name = "DIRECT",
                        Type = "Direct",
                    },
                },
            });
        }
    }

    private sealed class TestSnapshotCollector : IConnectionSnapshotCollector
    {
        private readonly List<string> _sequence;

        public TestSnapshotCollector(List<string> sequence)
        {
            _sequence = sequence;
        }

        public TaskCompletionSource<bool> Started { get; } = new(
            TaskCreationOptions.RunContinuationsAsynchronously);

        public async IAsyncEnumerable<MihomoConnectionsSnapshot> CollectAsync(
            ControllerEndpoint endpoint,
            string secret,
            [EnumeratorCancellation] CancellationToken cancellationToken)
        {
            _sequence.Add("stream");
            Started.TrySetResult(true);
            yield return new MihomoConnectionsSnapshot
            {
                UploadTotal = 0,
                DownloadTotal = 0,
                Connections = [],
            };
            await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken);
        }
    }

    private sealed class StalledSnapshotCollector : IConnectionSnapshotCollector
    {
        public async IAsyncEnumerable<MihomoConnectionsSnapshot> CollectAsync(
            ControllerEndpoint endpoint,
            string secret,
            [EnumeratorCancellation] CancellationToken cancellationToken)
        {
            await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken);
            yield break;
        }
    }

    private sealed class SessionTrackingCollector : IConnectionSnapshotCollector
    {
        private int _activeRuns;
        private int _maximumConcurrentRuns;
        private int _runCount;
        private readonly TaskCompletionSource<bool> _firstCleanupRelease = new(
            TaskCreationOptions.RunContinuationsAsynchronously);

        public SemaphoreSlim Started { get; } = new(0);

        public TaskCompletionSource<bool> FirstCleanupStarted { get; } = new(
            TaskCreationOptions.RunContinuationsAsynchronously);

        public int MaximumConcurrentRuns => Volatile.Read(ref _maximumConcurrentRuns);

        public int RunCount => Volatile.Read(ref _runCount);

        public async IAsyncEnumerable<MihomoConnectionsSnapshot> CollectAsync(
            ControllerEndpoint endpoint,
            string secret,
            [EnumeratorCancellation] CancellationToken cancellationToken)
        {
            var activeRuns = Interlocked.Increment(ref _activeRuns);
            var runNumber = Interlocked.Increment(ref _runCount);
            UpdateMaximum(activeRuns);
            Started.Release();
            try
            {
                yield return new MihomoConnectionsSnapshot
                {
                    UploadTotal = 0,
                    DownloadTotal = 0,
                    Connections = [],
                };
                await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken);
            }
            finally
            {
                if (runNumber == 1)
                {
                    FirstCleanupStarted.TrySetResult(true);
                    await _firstCleanupRelease.Task.ConfigureAwait(false);
                }

                Interlocked.Decrement(ref _activeRuns);
            }
        }

        public void ReleaseFirstCleanup()
        {
            _firstCleanupRelease.TrySetResult(true);
        }

        private void UpdateMaximum(int activeRuns)
        {
            while (true)
            {
                var current = Volatile.Read(ref _maximumConcurrentRuns);
                if (activeRuns <= current
                    || Interlocked.CompareExchange(
                        ref _maximumConcurrentRuns,
                        activeRuns,
                        current) == current)
                {
                    return;
                }
            }
        }
    }

    private sealed class TestConfigurationStore : IControllerConfigurationStore
    {
        private readonly List<string> _sequence;

        public TestConfigurationStore(List<string> sequence)
        {
            _sequence = sequence;
        }

        public int SaveCount { get; private set; }

        public string? SavedAddress { get; private set; }

        public string? SavedSecret { get; private set; }

        public Task<ControllerConfiguration> LoadAsync(CancellationToken cancellationToken)
        {
            return Task.FromResult(ControllerConfiguration.Empty);
        }

        public Task SaveValidatedAsync(
            ControllerEndpoint endpoint,
            string secret,
            CancellationToken cancellationToken)
        {
            _sequence.Add("save");
            SaveCount += 1;
            SavedAddress = endpoint.NormalizedAddress;
            SavedSecret = secret;
            return Task.CompletedTask;
        }
    }
}
