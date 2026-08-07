using System.ComponentModel;
using System.Runtime.CompilerServices;
using Microsoft.UI.Dispatching;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed class MainWindowViewModel : INotifyPropertyChanged
{
    private readonly DispatcherQueue _dispatcherQueue;
    private readonly IControllerConfigurationStore _configurationStore;
    private readonly TrafficMonitoringCoordinator _coordinator;
    private string _address = string.Empty;
    private MonitorConnectionState _connectionState = MonitorConnectionState.Disconnected;
    private string _stateTitle = "未连接";
    private string _message = "尚未连接 Mihomo Controller。";
    private string _versionText = "Mihomo 版本：--";
    private string _coverageText = "分类覆盖率：--";
    private string _proxyRateText = "↑ --  ·  ↓ --";
    private string _directRateText = "↑ --  ·  ↓ --";
    private string _rejectRateText = "↑ --  ·  ↓ --";
    private string _unknownRateText = "↑ --  ·  ↓ --";

    internal MainWindowViewModel(
        DispatcherQueue dispatcherQueue,
        IControllerConfigurationStore configurationStore,
        TrafficMonitoringCoordinator coordinator)
    {
        _dispatcherQueue = dispatcherQueue;
        _configurationStore = configurationStore;
        _coordinator = coordinator;
        _coordinator.SnapshotChanged += Coordinator_SnapshotChanged;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public event Action<string>? StatusSummaryChanged;

    public string Address
    {
        get => _address;
        set => SetField(ref _address, value);
    }

    public string StateTitle
    {
        get => _stateTitle;
        private set => SetField(ref _stateTitle, value);
    }

    public string Message
    {
        get => _message;
        private set => SetField(ref _message, value);
    }

    public string VersionText
    {
        get => _versionText;
        private set => SetField(ref _versionText, value);
    }

    public string CoverageText
    {
        get => _coverageText;
        private set => SetField(ref _coverageText, value);
    }

    public string ProxyRateText
    {
        get => _proxyRateText;
        private set => SetField(ref _proxyRateText, value);
    }

    public string DirectRateText
    {
        get => _directRateText;
        private set => SetField(ref _directRateText, value);
    }

    public string RejectRateText
    {
        get => _rejectRateText;
        private set => SetField(ref _rejectRateText, value);
    }

    public string UnknownRateText
    {
        get => _unknownRateText;
        private set => SetField(ref _unknownRateText, value);
    }

    public bool CanConnect => _connectionState
        is not (MonitorConnectionState.Connecting or MonitorConnectionState.Reconnecting);

    public bool CanDisconnect => _connectionState != MonitorConnectionState.Disconnected;

    public string ConnectButtonText => _connectionState == MonitorConnectionState.Connected
        ? "重新连接"
        : "连接";

    internal async Task<bool> InitializeAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var configuration = await _configurationStore
                .LoadAsync(cancellationToken)
                .ConfigureAwait(true);
            Address = configuration.Address;
            if (Address.Length == 0)
            {
                return false;
            }

            var endpoint = new ControllerEndpoint(Address);
            Address = endpoint.NormalizedAddress;
            await _coordinator
                .StartAsync(Address, configuration.Secret, false, cancellationToken)
                .ConfigureAwait(true);
            return true;
        }
        catch (Exception exception) when (
            exception is ControllerConfigurationException or ControllerEndpointException)
        {
            ShowError(exception.Message);
            return false;
        }
    }

    internal async Task ConnectAsync(
        string secret,
        bool forceEmptySecret,
        CancellationToken cancellationToken = default)
    {
        Address = Address.Trim();
        var endpoint = new ControllerEndpoint(Address);
        Address = endpoint.NormalizedAddress;
        var resolvedSecret = forceEmptySecret
            ? string.Empty
            : await ResolveSecretAsync(endpoint, secret, cancellationToken).ConfigureAwait(true);
        await _coordinator
            .StartAsync(Address, resolvedSecret, true, cancellationToken)
            .ConfigureAwait(true);
    }

    internal Task DisconnectAsync(CancellationToken cancellationToken = default)
    {
        return _coordinator.StopAsync(cancellationToken);
    }

    internal void ShowError(string message)
    {
        ApplySnapshot(new TrafficMonitorSnapshot(
            MonitorConnectionState.Disconnected,
            message));
    }

    internal void Detach()
    {
        _coordinator.SnapshotChanged -= Coordinator_SnapshotChanged;
    }

    private void Coordinator_SnapshotChanged(TrafficMonitorSnapshot snapshot)
    {
        if (_dispatcherQueue.HasThreadAccess)
        {
            ApplySnapshotIfCurrent(snapshot);
            return;
        }

        _ = _dispatcherQueue.TryEnqueue(() => ApplySnapshotIfCurrent(snapshot));
    }

    private void ApplySnapshotIfCurrent(TrafficMonitorSnapshot snapshot)
    {
        if (_coordinator.IsCurrentSession(snapshot.SessionGeneration))
        {
            ApplySnapshot(snapshot);
        }
    }

    private void ApplySnapshot(TrafficMonitorSnapshot snapshot)
    {
        _connectionState = snapshot.State;
        StateTitle = TitleFor(snapshot.State);
        Message = snapshot.Message;
        VersionText = snapshot.MihomoVersion is null
            ? "Mihomo 版本：--"
            : $"Mihomo 版本：{snapshot.MihomoVersion}";
        CoverageText = snapshot.Coverage is null
            ? "分类覆盖率：--"
            : $"分类覆盖率：{snapshot.Coverage.Value:P1}";
        ProxyRateText = TrafficDisplayFormatter.Rate(snapshot.Rates?.Proxy);
        DirectRateText = TrafficDisplayFormatter.Rate(snapshot.Rates?.Direct);
        RejectRateText = TrafficDisplayFormatter.Rate(snapshot.Rates?.Reject);
        UnknownRateText = TrafficDisplayFormatter.Rate(snapshot.Rates?.Unknown);
        OnPropertyChanged(nameof(CanConnect));
        OnPropertyChanged(nameof(CanDisconnect));
        OnPropertyChanged(nameof(ConnectButtonText));
        StatusSummaryChanged?.Invoke(StateTitle);
    }

    private static string TitleFor(MonitorConnectionState state)
    {
        return state switch
        {
            MonitorConnectionState.Disconnected => "未连接",
            MonitorConnectionState.Connecting => "正在连接",
            MonitorConnectionState.Connected => "已连接",
            MonitorConnectionState.Stale => "数据已超时",
            MonitorConnectionState.Reconnecting => "正在重连",
            MonitorConnectionState.AuthenticationFailed => "鉴权失败",
            MonitorConnectionState.Unsupported => "响应不兼容",
            _ => "未知状态",
        };
    }

    private async Task<string> ResolveSecretAsync(
        ControllerEndpoint endpoint,
        string enteredSecret,
        CancellationToken cancellationToken)
    {
        if (enteredSecret.Length > 0)
        {
            return enteredSecret;
        }

        var stored = await _configurationStore
            .LoadAsync(cancellationToken)
            .ConfigureAwait(true);
        if (stored.Secret.Length == 0 || stored.Address.Length == 0)
        {
            return string.Empty;
        }

        try
        {
            var storedEndpoint = new ControllerEndpoint(stored.Address);
            return string.Equals(
                endpoint.NormalizedAddress,
                storedEndpoint.NormalizedAddress,
                StringComparison.Ordinal)
                ? stored.Secret
                : string.Empty;
        }
        catch (ControllerEndpointException)
        {
            return string.Empty;
        }
    }

    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return false;
        }

        field = value;
        OnPropertyChanged(name);
        return true;
    }

    private void OnPropertyChanged([CallerMemberName] string? name = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
