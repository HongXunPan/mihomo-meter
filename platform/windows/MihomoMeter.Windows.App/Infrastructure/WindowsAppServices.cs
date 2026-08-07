using MihomoMeter.Windows.App.Infrastructure.Configuration;
using MihomoMeter.Windows.App.Infrastructure.Credentials;
using MihomoMeter.Windows.App.Infrastructure.Statistics;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;
using MihomoMeter.Windows.Core.Infrastructure.Statistics;

namespace MihomoMeter.Windows.App.Infrastructure;

internal sealed class WindowsAppServices : IAsyncDisposable
{
    private readonly HttpClient _httpClient;

    private WindowsAppServices(
        HttpClient httpClient,
        IControllerConfigurationStore configurationStore,
        TrafficStatisticsCoordinator statistics,
        TrafficMonitoringCoordinator coordinator)
    {
        _httpClient = httpClient;
        ConfigurationStore = configurationStore;
        Statistics = statistics;
        Coordinator = coordinator;
    }

    public IControllerConfigurationStore ConfigurationStore { get; }

    public TrafficMonitoringCoordinator Coordinator { get; }

    public TrafficStatisticsCoordinator Statistics { get; }

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
        var coordinator = new TrafficMonitoringCoordinator(
            controllerClient,
            new ConnectionSnapshotCollector(),
            configurationStore,
            statisticsRecorder: statistics);
        return new WindowsAppServices(
            httpClient,
            configurationStore,
            statistics,
            coordinator);
    }

    public async ValueTask DisposeAsync()
    {
        await Coordinator.DisposeAsync().ConfigureAwait(false);
        await Statistics.DisposeAsync().ConfigureAwait(false);
        _httpClient.Dispose();
    }
}
