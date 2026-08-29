using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;
using MihomoMeter.Windows.Core.Infrastructure.Quota;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class QuotaTrackingCoordinatorProfileTests
{
    private string _testDirectory = string.Empty;
    private string _databasePath = string.Empty;

    [TestInitialize]
    public void SetUp()
    {
        WindowsSqliteTestProvider.Initialize();
        _testDirectory = Path.Combine(
            AppContext.BaseDirectory,
            "QuotaCoordinatorData",
            Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_testDirectory);
        _databasePath = Path.Combine(_testDirectory, "quota.sqlite3");
    }

    [TestCleanup]
    public void TearDown()
    {
        if (Directory.Exists(_testDirectory))
        {
            Directory.Delete(_testDirectory, true);
        }
    }

    [TestMethod]
    public async Task ClearingDirectoryPreservesActiveTrackingIntent()
    {
        var catalogReader = new CatalogReader(HttpsCatalog());
        var queryClient = new QueryClient();
        await using var coordinator = CreateCoordinator(catalogReader, queryClient);
        await coordinator.PrepareAsync();
        await coordinator.SetProfileDirectoryAsync(_testDirectory);
        await coordinator.SetProfileTrackingAsync("profile-a", true);

        await coordinator.ClearProfileDirectoryAsync();
        await coordinator.RefreshAllProfilesAsync();

        Assert.AreEqual(
            SubscriptionTrackingStatus.Active,
            coordinator.CurrentState.Ledger.Subscriptions.Single().Subscription.Status);
        Assert.AreEqual(0, queryClient.QueryCount);
    }

    [TestMethod]
    public async Task ReconciliationFollowsProfileAvailabilityAndHttpsSupport()
    {
        var catalogReader = new CatalogReader(HttpsCatalog());
        await using var coordinator = CreateCoordinator(catalogReader, new QueryClient());
        await coordinator.PrepareAsync();
        await coordinator.SetProfileDirectoryAsync(_testDirectory);
        await coordinator.SetProfileTrackingAsync("profile-a", true);

        catalogReader.Catalog = ClashProfileCatalog.Empty;
        await coordinator.SetProfileDirectoryAsync(_testDirectory);
        AssertStatus(coordinator, SubscriptionTrackingStatus.Unsupported);

        catalogReader.Catalog = HttpsCatalog("恢复后的订阅");
        await coordinator.SetProfileDirectoryAsync(_testDirectory);
        AssertStatus(coordinator, SubscriptionTrackingStatus.Active);
        Assert.AreEqual(
            "恢复后的订阅",
            coordinator.CurrentState.Ledger.Subscriptions.Single().Subscription.Name);

        catalogReader.Catalog = HttpCatalog();
        await coordinator.SetProfileDirectoryAsync(_testDirectory);
        AssertStatus(coordinator, SubscriptionTrackingStatus.Unsupported);

        catalogReader.Catalog = HttpsCatalog();
        await coordinator.SetProfileDirectoryAsync(_testDirectory);
        AssertStatus(coordinator, SubscriptionTrackingStatus.Active);
    }

    [TestMethod]
    public async Task SupportedProfileKeepsExplicitPausedStatus()
    {
        var catalogReader = new CatalogReader(HttpsCatalog());
        await using var coordinator = CreateCoordinator(catalogReader, new QueryClient());
        await coordinator.PrepareAsync();
        await coordinator.SetProfileDirectoryAsync(_testDirectory);
        await coordinator.SetProfileTrackingAsync("profile-a", true);
        await coordinator.SetProfileTrackingAsync("profile-a", false);

        catalogReader.Catalog = HttpsCatalog("重命名但仍受支持");
        await coordinator.SetProfileDirectoryAsync(_testDirectory);

        AssertStatus(coordinator, SubscriptionTrackingStatus.Paused);
    }

    [TestMethod]
    public async Task ActiveQueryRecordsSanitizedLifecycleEvents()
    {
        var catalogReader = new CatalogReader(HttpsCatalog());
        var diagnostics = new RecordingDiagnosticEventSink();
        await using var coordinator = CreateCoordinator(
            catalogReader,
            new QueryClient(),
            diagnostics);
        await coordinator.PrepareAsync();
        await coordinator.SetProfileDirectoryAsync(_testDirectory);
        await coordinator.SetProfileTrackingAsync("profile-a", true);

        await coordinator.ControllerValidatedAsync(
            new ControllerEndpoint("127.0.0.1:9090"),
            "synthetic-secret",
            CancellationToken.None);
        var completed = await diagnostics.QueryFinished.Task.WaitAsync(TimeSpan.FromSeconds(2));

        Assert.AreEqual("succeeded", completed.Outcome);
        Assert.AreEqual("automatic", completed.Trigger);
        Assert.IsFalse(completed.Category.Contains("profile-a", StringComparison.Ordinal));
    }

    private QuotaTrackingCoordinator CreateCoordinator(
        CatalogReader catalogReader,
        QueryClient queryClient,
        IDiagnosticEventSink? diagnosticEventSink = null)
    {
        return new QuotaTrackingCoordinator(
            new SQLiteQuotaLedger(_databasePath),
            new ControllerClient(),
            new DirectoryStore(),
            catalogReader,
            new DirectoryObserver(),
            new Fingerprinter(),
            queryClient,
            new FixedTimeProvider(),
            diagnosticEventSink: diagnosticEventSink);
    }

    private static void AssertStatus(
        QuotaTrackingCoordinator coordinator,
        SubscriptionTrackingStatus expected)
    {
        Assert.AreEqual(
            expected,
            coordinator.CurrentState.Ledger.Subscriptions.Single().Subscription.Status);
    }

    private static ClashProfileCatalog HttpsCatalog(string name = "订阅 A")
    {
        return new ClashProfileCatalog(
            "profile-a",
            [new ClashProfile("profile-a", name, new Uri("https://example.com/sub"))],
            0);
    }

    private static ClashProfileCatalog HttpCatalog()
    {
        return new ClashProfileCatalog(
            "profile-a",
            [new ClashProfile("profile-a", "订阅 A", new Uri("http://example.com/sub"))],
            0);
    }

    private sealed class FixedTimeProvider : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() =>
            new(2026, 8, 29, 0, 0, 0, TimeSpan.Zero);
    }

    private sealed class CatalogReader(ClashProfileCatalog catalog) : IProfileCatalogReader
    {
        public ClashProfileCatalog Catalog { get; set; } = catalog;

        public ClashProfileCatalog Read(string directoryPath) => Catalog;
    }

    private sealed class DirectoryStore : IProfileDirectoryStore
    {
        public Task<string?> LoadAsync(CancellationToken cancellationToken) =>
            Task.FromResult<string?>(null);

        public Task SaveAsync(string directoryPath, CancellationToken cancellationToken) =>
            Task.CompletedTask;

        public Task ClearAsync(CancellationToken cancellationToken) => Task.CompletedTask;
    }

    private sealed class DirectoryObserver : IProfileDirectoryObserver
    {
        public event Action? Changed
        {
            add { }
            remove { }
        }

        public event Action? ObservationFailed
        {
            add { }
            remove { }
        }

        public void Start(string directoryPath)
        {
        }

        public void Stop()
        {
        }

        public void Dispose()
        {
        }
    }

    private sealed class Fingerprinter : IProfileUrlFingerprinter
    {
        public Task<string> FingerprintAsync(
            Uri uri,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(new string(uri.Scheme == "https" ? 'a' : 'b', 64));
        }
    }

    private sealed class QueryClient : IActiveQuotaQueryClient
    {
        public int QueryCount { get; private set; }

        public Task<ActiveQuotaQueryResult> QueryAsync(
            Uri subscriptionUri,
            MihomoLocalProxy proxy,
            string userAgent,
            CancellationToken cancellationToken)
        {
            QueryCount += 1;
            return Task.FromResult(new ActiveQuotaQueryResult(
                new QuotaTraffic(1, 2, 100),
                null));
        }
    }

    private sealed class RecordingDiagnosticEventSink : IDiagnosticEventSink
    {
        public TaskCompletionSource<DiagnosticExportEvent> QueryFinished { get; } = new(
            TaskCreationOptions.RunContinuationsAsynchronously);

        public void Record(DiagnosticExportEvent diagnosticEvent)
        {
            if (diagnosticEvent.Category == "profile_quota.query.finished")
            {
                QueryFinished.TrySetResult(diagnosticEvent);
            }
        }
    }

    private sealed class ControllerClient : IMihomoQuotaControllerClient
    {
        public Task<MihomoProxyProvidersResponse> FetchProxyProvidersAsync(
            ControllerEndpoint endpoint,
            string secret,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(new MihomoProxyProvidersResponse
            {
                Providers = [],
            });
        }

        public Task<MihomoQuotaConfigurationResponse> FetchQuotaConfigurationAsync(
            ControllerEndpoint endpoint,
            string secret,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(new MihomoQuotaConfigurationResponse
            {
                MixedPort = 7890,
                GlobalUserAgent = "clash.meta",
            });
        }
    }
}
