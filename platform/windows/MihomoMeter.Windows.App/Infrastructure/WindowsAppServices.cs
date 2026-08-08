using MihomoMeter.Windows.App.Infrastructure.Configuration;
using MihomoMeter.Windows.App.Infrastructure.Credentials;
using MihomoMeter.Windows.App.Infrastructure.Quota;
using MihomoMeter.Windows.App.Infrastructure.Statistics;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;
using MihomoMeter.Windows.Core.Infrastructure.Profile;
using MihomoMeter.Windows.Core.Infrastructure.Quota;
using MihomoMeter.Windows.Core.Infrastructure.Statistics;

namespace MihomoMeter.Windows.App.Infrastructure;

internal sealed class WindowsAppServices : IAsyncDisposable
{
    private readonly HttpClient _httpClient;

    private WindowsAppServices(
        HttpClient httpClient,
        IControllerConfigurationStore configurationStore,
        TrafficStatisticsCoordinator statistics,
        QuotaTrackingCoordinator quota,
        TrafficMonitoringCoordinator coordinator)
    {
        _httpClient = httpClient;
        ConfigurationStore = configurationStore;
        Statistics = statistics;
        Quota = quota;
        Coordinator = coordinator;
    }

    public IControllerConfigurationStore ConfigurationStore { get; }

    public TrafficMonitoringCoordinator Coordinator { get; }

    public TrafficStatisticsCoordinator Statistics { get; }

    public QuotaTrackingCoordinator Quota { get; }

    public static WindowsAppServices Create()
    {
        WindowsSqliteProvider.Initialize();
        var httpClient = new HttpClient(new SocketsHttpHandler
        {
            AllowAutoRedirect = false,
            UseProxy = false,
        });
        var controllerClient = new MihomoControllerClient(httpClient);
        var configurationStore = new ValidatedControllerConfigurationStore(
            new JsonControllerAddressStore(),
            new CredentialManagerSecretStore());
        var statistics = new TrafficStatisticsCoordinator(
            new SQLiteTrafficLedger(TrafficLedgerLocation.DefaultDatabasePath()));
        var quota = new QuotaTrackingCoordinator(
            new SQLiteQuotaLedger(QuotaLedgerLocation.DefaultDatabasePath()),
            controllerClient,
            new JsonProfileDirectoryStore(),
            new YamlClashProfileCatalogReader(),
            new ProfileDirectoryObserver(),
            new HmacProfileUrlFingerprinter(
                new CredentialManagerProfileFingerprintKeyStore()),
            new MihomoActiveQuotaQueryClient());
        var coordinator = new TrafficMonitoringCoordinator(
            controllerClient,
            new ConnectionSnapshotCollector(),
            configurationStore,
            statisticsRecorder: statistics,
            quotaTrackingLifecycle: quota);
        return new WindowsAppServices(
            httpClient,
            configurationStore,
            statistics,
            quota,
            coordinator);
    }

    public async ValueTask DisposeAsync()
    {
        await Coordinator.DisposeAsync().ConfigureAwait(false);
        await Statistics.DisposeAsync().ConfigureAwait(false);
        await Quota.DisposeAsync().ConfigureAwait(false);
        _httpClient.Dispose();
    }
}
