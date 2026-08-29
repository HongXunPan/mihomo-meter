using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Core.Application;

public sealed partial class QuotaTrackingCoordinator : IQuotaTrackingLifecycle, IAsyncDisposable
{
    private static readonly TimeSpan RuntimeObservationInterval = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan QueryScheduleInterval = TimeSpan.FromSeconds(30);
    private readonly IQuotaLedger _ledger;
    private readonly IMihomoQuotaControllerClient _controllerClient;
    private readonly IProfileDirectoryStore _directoryStore;
    private readonly IProfileCatalogReader _catalogReader;
    private readonly IProfileDirectoryObserver _directoryObserver;
    private readonly IProfileUrlFingerprinter _fingerprinter;
    private readonly IActiveQuotaQueryClient _activeQueryClient;
    private readonly ProfileQuotaSchedulePolicy _schedulePolicy;
    private readonly IDiagnosticEventSink _diagnosticEventSink;
    private readonly TimeProvider _timeProvider;
    private readonly SemaphoreSlim _operationGate = new(1, 1);
    private readonly QuotaQueryGate _queryGate = new();
    private readonly SemaphoreSlim _networkTransitionGate = new(1, 1);
    private readonly object _stateLock = new();
    private readonly object _networkSourceLock = new();
    private QuotaTrackingState _currentState;
    private QuotaLedgerSnapshot _ledgerSnapshot;
    private ClashProfileCatalog _catalog = ClashProfileCatalog.Empty;
    private string? _profileDirectoryPath;
    private RuntimeQuotaObservationStatus _runtimeStatus =
        RuntimeQuotaObservationStatus.ControllerUnavailable;
    private RuntimeQuotaCandidate? _latestRuntimeCandidate;
    private int _runtimeCandidateCount;
    private string? _runtimeSourceKey;
    private ControllerEndpoint? _endpoint;
    private ControllerEndpoint? _lastValidatedEndpoint;
    private string _secret = string.Empty;
    private MihomoQuotaRuntimeConfiguration? _runtimeConfiguration;
    private CancellationTokenSource? _networkSource;
    private Task? _runtimeTask;
    private Task? _queryScheduleTask;
    private string? _message;
    private bool _operationInProgress;
    private bool _ledgerAvailable;

    public QuotaTrackingCoordinator(
        IQuotaLedger ledger,
        IMihomoQuotaControllerClient controllerClient,
        IProfileDirectoryStore directoryStore,
        IProfileCatalogReader catalogReader,
        IProfileDirectoryObserver directoryObserver,
        IProfileUrlFingerprinter fingerprinter,
        IActiveQuotaQueryClient activeQueryClient,
        TimeProvider? timeProvider = null,
        ProfileQuotaSchedulePolicy? schedulePolicy = null,
        IDiagnosticEventSink? diagnosticEventSink = null)
    {
        _ledger = ledger;
        _controllerClient = controllerClient;
        _directoryStore = directoryStore;
        _catalogReader = catalogReader;
        _directoryObserver = directoryObserver;
        _fingerprinter = fingerprinter;
        _activeQueryClient = activeQueryClient;
        _timeProvider = timeProvider ?? TimeProvider.System;
        _schedulePolicy = schedulePolicy ?? new ProfileQuotaSchedulePolicy();
        _diagnosticEventSink = diagnosticEventSink ?? NullDiagnosticEventSink.Instance;
        var now = _timeProvider.GetUtcNow();
        _ledgerSnapshot = QuotaLedgerSnapshot.Empty(now);
        _currentState = QuotaTrackingState.Loading(now);
        _directoryObserver.Changed += DirectoryObserver_Changed;
        _directoryObserver.ObservationFailed += DirectoryObserver_ObservationFailed;
    }

    public event Action<QuotaTrackingState>? StateChanged;

    public QuotaTrackingState CurrentState
    {
        get
        {
            lock (_stateLock)
            {
                return _currentState;
            }
        }
    }

    public async Task PrepareAsync(CancellationToken cancellationToken = default)
    {
        await ExecuteOperationAsync(async () =>
        {
            _ledgerSnapshot = await _ledger
                .PrepareAsync(_timeProvider.GetUtcNow(), cancellationToken)
                .ConfigureAwait(false);
            _ledgerAvailable = true;
            var runtime = RuntimeSubscription();
            if (runtime?.Status == SubscriptionTrackingStatus.Active)
            {
                var now = _timeProvider.GetUtcNow();
                _ledgerSnapshot = await _ledger
                    .SetSubscriptionStatusAsync(
                        runtime.Id,
                        SubscriptionTrackingStatus.Paused,
                        now,
                        cancellationToken)
                    .ConfigureAwait(false);
                _message = "应用重启后需要重新确认当前运行订阅。";
            }

            _profileDirectoryPath = await _directoryStore
                .LoadAsync(cancellationToken)
                .ConfigureAwait(false);
            if (_profileDirectoryPath is not null)
            {
                await RefreshCatalogCoreAsync(cancellationToken).ConfigureAwait(false);
                _directoryObserver.Start(_profileDirectoryPath);
            }

            Publish(QuotaAvailability.Available);
        }, cancellationToken).ConfigureAwait(false);
    }

    public async Task ControllerValidatedAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken)
    {
        await _networkTransitionGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await StopNetworkTasksAsync().ConfigureAwait(false);
            MihomoQuotaRuntimeConfiguration? configuration = null;
            try
            {
                var response = await _controllerClient
                    .FetchQuotaConfigurationAsync(endpoint, secret, cancellationToken)
                    .ConfigureAwait(false);
                configuration = response.ToRuntimeConfiguration();
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                configuration = null;
            }

            var canStart = true;
            await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                if (!_ledgerAvailable)
                {
                    canStart = false;
                    return;
                }

                if (_lastValidatedEndpoint is not null
                    && !string.Equals(
                        _lastValidatedEndpoint.NormalizedAddress,
                        endpoint.NormalizedAddress,
                        StringComparison.Ordinal))
                {
                    await PauseRuntimeSubscriptionCoreAsync(
                        "Controller 地址变化，轻量追踪已暂停。",
                        cancellationToken).ConfigureAwait(false);
                }

                _endpoint = endpoint;
                _lastValidatedEndpoint = endpoint;
                _secret = secret;
                _runtimeConfiguration = configuration;
                _runtimeStatus = RuntimeQuotaObservationStatus.Checking;
                _message = configuration?.Proxy is null
                    ? "Mihomo 未暴露本地代理端口，指定 Profile 查询暂不可用。"
                    : null;
                Publish(QuotaAvailability.Available);
            }
            catch (QuotaLedgerException exception)
            {
                canStart = false;
                _ledgerAvailable = false;
                _endpoint = null;
                _secret = string.Empty;
                _runtimeConfiguration = null;
                _runtimeStatus = RuntimeQuotaObservationStatus.Failed;
                _message = exception.Message;
                Publish(QuotaAvailability.Unavailable);
            }
            finally
            {
                _operationGate.Release();
            }

            if (!canStart)
            {
                return;
            }

            var source = new CancellationTokenSource();
            lock (_networkSourceLock)
            {
                _networkSource = source;
            }
            _runtimeTask = RunRuntimeObservationAsync(source.Token);
            _queryScheduleTask = RunQueryScheduleAsync(source.Token);
        }
        finally
        {
            _networkTransitionGate.Release();
        }
    }

    public async Task ControllerUnavailableAsync(CancellationToken cancellationToken)
    {
        await _networkTransitionGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await StopNetworkTasksAsync().ConfigureAwait(false);
            await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                _endpoint = null;
                _secret = string.Empty;
                _runtimeConfiguration = null;
                _latestRuntimeCandidate = null;
                _runtimeStatus = RuntimeQuotaObservationStatus.ControllerUnavailable;
                _runtimeCandidateCount = 0;
                Publish(QuotaAvailability.Available);
            }
            finally
            {
                _operationGate.Release();
            }
        }
        finally
        {
            _networkTransitionGate.Release();
        }
    }

    public async ValueTask DisposeAsync()
    {
        await _networkTransitionGate.WaitAsync().ConfigureAwait(false);
        try
        {
            await StopNetworkTasksAsync().ConfigureAwait(false);
        }
        finally
        {
            _networkTransitionGate.Release();
        }

        _directoryObserver.Changed -= DirectoryObserver_Changed;
        _directoryObserver.ObservationFailed -= DirectoryObserver_ObservationFailed;
        _directoryObserver.Dispose();
        await _ledger.DisposeAsync().ConfigureAwait(false);
        _operationGate.Dispose();
        _queryGate.Dispose();
        _networkTransitionGate.Dispose();
    }

}
