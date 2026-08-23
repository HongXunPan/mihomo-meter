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
            new[] { "version", "proxies", "configs", "save", "stream" },
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
    public async Task RuntimeConfigurationFailureDoesNotBlockMonitoringStream()
    {
        var sequence = new List<string>();
        var collector = new TestSnapshotCollector(sequence);
        var client = new TestControllerClient(sequence)
        {
            RuntimeConfigurationFailure = new MihomoControllerException(
                MihomoControllerError.UnsupportedResponse),
        };
        await using var coordinator = new TrafficMonitoringCoordinator(
            client,
            collector,
            new TestConfigurationStore(sequence));

        await coordinator.StartAsync("127.0.0.1:9090", string.Empty, false);
        await collector.Started.Task.WaitAsync(TimeSpan.FromSeconds(2));

        CollectionAssert.AreEqual(
            new[] { "version", "proxies", "configs", "stream" },
            sequence);
    }

    [TestMethod]
    public async Task PublishesRuntimeConfigurationWithConnectedSnapshot()
    {
        var sequence = new List<string>();
        var connected = new TaskCompletionSource<TrafficMonitorSnapshot>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        await using var coordinator = new TrafficMonitoringCoordinator(
            new TestControllerClient(sequence),
            new TestSnapshotCollector(sequence),
            new TestConfigurationStore(sequence));
        coordinator.SnapshotChanged += snapshot =>
        {
            if (snapshot.State == MonitorConnectionState.Connected)
            {
                connected.TrySetResult(snapshot);
            }
        };

        await coordinator.StartAsync("127.0.0.1:9090", string.Empty, false);
        var snapshot = await connected.Task.WaitAsync(TimeSpan.FromSeconds(2));

        Assert.IsNotNull(snapshot.RuntimeConfiguration);
        Assert.AreEqual("rule", snapshot.RuntimeConfiguration.Mode);
        Assert.AreEqual(true, snapshot.RuntimeConfiguration.IsTunEnabled);
        Assert.AreEqual("system", snapshot.RuntimeConfiguration.TunStack);
        Assert.AreEqual(true, snapshot.RuntimeConfiguration.AutomaticallyRoutesTraffic);
        Assert.AreEqual(true, snapshot.RuntimeConfiguration.IsIPv6Enabled);
        Assert.AreEqual(false, snapshot.RuntimeConfiguration.AllowsLan);
        Assert.AreEqual(7890, snapshot.RuntimeConfiguration.MixedPort);
        Assert.AreEqual(
            MihomoProcessMatchingMode.Strict,
            snapshot.RuntimeConfiguration.ProcessMatchingMode);
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

    [TestMethod]
    public async Task StopAndDisposeUseTypedMonitoringInterruptionReasons()
    {
        var recorder = new RecordingStatisticsRecorder();
        var coordinator = new TrafficMonitoringCoordinator(
            new TestControllerClient([]),
            new TestSnapshotCollector([]),
            new TestConfigurationStore([]),
            statisticsRecorder: recorder);

        await coordinator.StopAsync();
        await coordinator.DisposeAsync();

        CollectionAssert.AreEqual(
            new[]
            {
                TrafficSessionEndReason.MonitoringStopped,
                TrafficSessionEndReason.ApplicationExit,
            },
            recorder.InterruptionReasons);
    }

    [TestMethod]
    public async Task SystemEnvironmentPauseRecoversValidatedConnectionOnce()
    {
        var sequence = new List<string>();
        var collector = new TestSnapshotCollector(sequence);
        var recorder = new RecordingStatisticsRecorder();
        var store = new TestConfigurationStore(sequence)
        {
            LoadedConfiguration = new ControllerConfiguration(
                "http://127.0.0.1:9090",
                "synthetic-secret"),
        };
        await using var coordinator = new TrafficMonitoringCoordinator(
            new TestControllerClient(sequence),
            collector,
            store,
            statisticsRecorder: recorder);

        await coordinator.StartAsync("127.0.0.1:9090", "synthetic-secret", false);
        await collector.Started.Task.WaitAsync(TimeSpan.FromSeconds(2));
        await coordinator.SetSystemEnvironmentAvailableAsync(false);
        await coordinator.SetSystemEnvironmentAvailableAsync(false);

        Assert.IsTrue(coordinator.IsConnectionExpected);
        Assert.IsFalse(coordinator.IsSystemEnvironmentAvailable);
        CollectionAssert.Contains(
            recorder.InterruptionReasons,
            TrafficSessionEndReason.Recovery);

        await coordinator.SetSystemEnvironmentAvailableAsync(true);
        await WaitForCollectionCountAsync(collector, 2);
        Assert.AreEqual(2, collector.CollectionCount);
    }

    [TestMethod]
    public async Task UserStopWhileEnvironmentUnavailablePreventsRecovery()
    {
        var sequence = new List<string>();
        var collector = new TestSnapshotCollector(sequence);
        var store = new TestConfigurationStore(sequence)
        {
            LoadedConfiguration = new ControllerConfiguration(
                "http://127.0.0.1:9090",
                "synthetic-secret"),
        };
        await using var coordinator = new TrafficMonitoringCoordinator(
            new TestControllerClient(sequence),
            collector,
            store);

        await coordinator.StartAsync("127.0.0.1:9090", "synthetic-secret", false);
        await collector.Started.Task.WaitAsync(TimeSpan.FromSeconds(2));
        await coordinator.SetSystemEnvironmentAvailableAsync(false);
        await coordinator.StopAsync();
        await coordinator.SetSystemEnvironmentAvailableAsync(true);
        await Task.Delay(TimeSpan.FromMilliseconds(50));

        Assert.IsFalse(coordinator.IsConnectionExpected);
        Assert.AreEqual(1, collector.CollectionCount);
    }

    [TestMethod]
    public async Task TerminalAuthenticationFailureDoesNotBecomeRecoveryCandidate()
    {
        var sequence = new List<string>();
        var terminalSnapshot = new TaskCompletionSource<bool>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        var store = new TestConfigurationStore(sequence)
        {
            LoadedConfiguration = new ControllerConfiguration(
                "http://127.0.0.1:9090",
                "synthetic-secret"),
        };
        await using var coordinator = new TrafficMonitoringCoordinator(
            new TestControllerClient(sequence)
            {
                VersionFailure = new MihomoControllerException(
                    MihomoControllerError.AuthenticationFailed),
            },
            new TestSnapshotCollector(sequence),
            store);
        coordinator.SnapshotChanged += snapshot =>
        {
            if (snapshot.State == MonitorConnectionState.AuthenticationFailed)
            {
                terminalSnapshot.TrySetResult(true);
            }
        };

        await coordinator.StartAsync("127.0.0.1:9090", "synthetic-secret", false);
        await terminalSnapshot.Task.WaitAsync(TimeSpan.FromSeconds(2));
        await coordinator.SetSystemEnvironmentAvailableAsync(false);
        await coordinator.SetSystemEnvironmentAvailableAsync(true);
        await Task.Delay(TimeSpan.FromMilliseconds(50));

        CollectionAssert.AreEqual(new[] { "version" }, sequence);
    }

    [TestMethod]
    public async Task AnalyticsFailureDoesNotBlockRealtimeMonitoringOrStop()
    {
        var sequence = new List<string>();
        var analytics = new ThrowingAnalyticsRecorder();
        var connected = new TaskCompletionSource<bool>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        await using var coordinator = new TrafficMonitoringCoordinator(
            new TestControllerClient(sequence),
            new TestSnapshotCollector(sequence),
            new TestConfigurationStore(sequence),
            connectionAnalyticsRecorder: analytics);
        coordinator.SnapshotChanged += snapshot =>
        {
            if (snapshot.State == MonitorConnectionState.Connected)
            {
                connected.TrySetResult(true);
            }
        };

        await coordinator.StartAsync("127.0.0.1:9090", string.Empty, false);
        Assert.IsTrue(await connected.Task.WaitAsync(TimeSpan.FromSeconds(2)));
        await coordinator.StopAsync();

        Assert.IsTrue(analytics.RecordCount > 0);
        Assert.IsTrue(analytics.FlushCount > 0);
    }

    private sealed class TestControllerClient : IMihomoControllerClient
    {
        private readonly List<string> _sequence;

        public TestControllerClient(List<string> sequence)
        {
            _sequence = sequence;
        }

        public Exception? VersionFailure { get; init; }

        public Exception? RuntimeConfigurationFailure { get; init; }

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

        public Task<MihomoRuntimeConfigurationResponse> FetchRuntimeConfigurationAsync(
            ControllerEndpoint endpoint,
            string secret,
            CancellationToken cancellationToken)
        {
            _sequence.Add("configs");
            return RuntimeConfigurationFailure is null
                ? Task.FromResult(new MihomoRuntimeConfigurationResponse
                {
                    FindProcessMode = "strict",
                    Mode = "rule",
                    AllowLan = false,
                    Ipv6 = true,
                    MixedPort = 7890,
                    Tun = new MihomoTunConfigurationResponse
                    {
                        Enable = true,
                        Stack = "system",
                        AutoRoute = true,
                    },
                })
                : Task.FromException<MihomoRuntimeConfigurationResponse>(
                    RuntimeConfigurationFailure);
        }
    }

    private sealed class RecordingStatisticsRecorder : ITrafficStatisticsRecorder
    {
        public List<TrafficSessionEndReason> InterruptionReasons { get; } = [];

        public Task BeginMonitoringAsync(
            string version,
            CancellationToken cancellationToken)
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
            InterruptionReasons.Add(reason);
            return Task.CompletedTask;
        }
    }

    private sealed class TestSnapshotCollector : IConnectionSnapshotCollector
    {
        private readonly List<string> _sequence;
        private int _collectionCount;

        public TestSnapshotCollector(List<string> sequence)
        {
            _sequence = sequence;
        }

        public TaskCompletionSource<bool> Started { get; } = new(
            TaskCreationOptions.RunContinuationsAsynchronously);

        public int CollectionCount => Volatile.Read(ref _collectionCount);

        public async IAsyncEnumerable<MihomoConnectionsSnapshot> CollectAsync(
            ControllerEndpoint endpoint,
            string secret,
            [EnumeratorCancellation] CancellationToken cancellationToken)
        {
            _sequence.Add("stream");
            Interlocked.Increment(ref _collectionCount);
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

    private sealed class ThrowingAnalyticsRecorder : IConnectionAnalyticsRecorder
    {
        public int RecordCount { get; private set; }

        public int FlushCount { get; private set; }

        public Task RecordAsync(
            IReadOnlyList<ConnectionAttributionDelta> deltas,
            DateTimeOffset observedAt,
            CancellationToken cancellationToken)
        {
            RecordCount += 1;
            throw new InvalidOperationException("模拟连接归因记录失败");
        }

        public Task FlushPendingAsync(CancellationToken cancellationToken)
        {
            FlushCount += 1;
            throw new InvalidOperationException("模拟连接归因刷新失败");
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

        public ControllerConfiguration LoadedConfiguration { get; init; } =
            ControllerConfiguration.Empty;

        public Task<ControllerConfiguration> LoadAsync(CancellationToken cancellationToken)
        {
            return Task.FromResult(LoadedConfiguration);
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

    private static async Task WaitForCollectionCountAsync(
        TestSnapshotCollector collector,
        int expectedCount)
    {
        for (var attempt = 0; attempt < 100 && collector.CollectionCount < expectedCount; attempt++)
        {
            await Task.Delay(TimeSpan.FromMilliseconds(10));
        }
    }
}
