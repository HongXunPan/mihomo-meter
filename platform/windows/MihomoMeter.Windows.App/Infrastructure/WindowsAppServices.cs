using MihomoMeter.Windows.App.Infrastructure.Configuration;
using MihomoMeter.Windows.App.Infrastructure.Credentials;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.App.Infrastructure;

internal sealed class WindowsAppServices : IAsyncDisposable
{
    private readonly HttpClient _httpClient;

    private WindowsAppServices(
        HttpClient httpClient,
        IControllerConfigurationStore configurationStore,
        TrafficMonitoringCoordinator coordinator)
    {
        _httpClient = httpClient;
        ConfigurationStore = configurationStore;
        Coordinator = coordinator;
    }

    public IControllerConfigurationStore ConfigurationStore { get; }

    public TrafficMonitoringCoordinator Coordinator { get; }

    public static WindowsAppServices Create()
    {
        var httpClient = new HttpClient(new SocketsHttpHandler
        {
            AllowAutoRedirect = false,
            UseProxy = false,
        });
        var controllerClient = new MihomoControllerClient(httpClient);
        var configurationStore = new ValidatedControllerConfigurationStore(
            new JsonControllerAddressStore(),
            new CredentialManagerSecretStore());
        var coordinator = new TrafficMonitoringCoordinator(
            controllerClient,
            new ConnectionSnapshotCollector(),
            configurationStore);
        return new WindowsAppServices(httpClient, configurationStore, coordinator);
    }

    public async ValueTask DisposeAsync()
    {
        await Coordinator.DisposeAsync().ConfigureAwait(false);
        _httpClient.Dispose();
    }
}
