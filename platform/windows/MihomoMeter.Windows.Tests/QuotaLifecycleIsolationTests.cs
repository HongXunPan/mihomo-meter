using System.Runtime.CompilerServices;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class QuotaLifecycleIsolationTests
{
    [TestMethod]
    public async Task QuotaFailureDoesNotBlockRealtimeMonitoringOrStop()
    {
        var connected = new TaskCompletionSource<bool>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        var quota = new ThrowingQuotaLifecycle();
        await using var coordinator = new TrafficMonitoringCoordinator(
            new ControllerClient(),
            new SnapshotCollector(),
            new ConfigurationStore(),
            quotaTrackingLifecycle: quota);
        coordinator.SnapshotChanged += snapshot =>
        {
            if (snapshot.State == MonitorConnectionState.Connected)
            {
                connected.TrySetResult(true);
            }
        };

        await coordinator.StartAsync("127.0.0.1:9090", "synthetic-secret", false);
        Assert.IsTrue(await connected.Task.WaitAsync(TimeSpan.FromSeconds(2)));

        await coordinator.StopAsync();

        Assert.IsTrue(quota.ValidatedCount > 0);
        Assert.IsTrue(quota.UnavailableCount > 0);
    }

    private sealed class ThrowingQuotaLifecycle : IQuotaTrackingLifecycle
    {
        public int ValidatedCount { get; private set; }

        public int UnavailableCount { get; private set; }

        public Task ControllerValidatedAsync(
            ControllerEndpoint endpoint,
            string secret,
            CancellationToken cancellationToken)
        {
            ValidatedCount += 1;
            throw new InvalidOperationException("模拟配额初始化失败");
        }

        public Task ControllerUnavailableAsync(CancellationToken cancellationToken)
        {
            UnavailableCount += 1;
            throw new InvalidOperationException("模拟配额停止失败");
        }
    }

    private sealed class ControllerClient : IMihomoControllerClient
    {
        public Task<MihomoVersionResponse> FetchVersionAsync(
            ControllerEndpoint endpoint,
            string secret,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(new MihomoVersionResponse
            {
                Meta = true,
                Version = "v1.19.29",
            });
        }

        public Task<MihomoProxiesResponse> FetchProxiesAsync(
            ControllerEndpoint endpoint,
            string secret,
            CancellationToken cancellationToken)
        {
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
            return Task.FromResult(new MihomoRuntimeConfigurationResponse
            {
                FindProcessMode = "strict",
            });
        }
    }

    private sealed class SnapshotCollector : IConnectionSnapshotCollector
    {
        public async IAsyncEnumerable<MihomoConnectionsSnapshot> CollectAsync(
            ControllerEndpoint endpoint,
            string secret,
            [EnumeratorCancellation] CancellationToken cancellationToken)
        {
            yield return new MihomoConnectionsSnapshot
            {
                UploadTotal = 0,
                DownloadTotal = 0,
                Connections = [],
            };
            await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken);
        }
    }

    private sealed class ConfigurationStore : IControllerConfigurationStore
    {
        public Task<ControllerConfiguration> LoadAsync(CancellationToken cancellationToken)
        {
            return Task.FromResult(ControllerConfiguration.Empty);
        }

        public Task SaveValidatedAsync(
            ControllerEndpoint endpoint,
            string secret,
            CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }
    }
}
