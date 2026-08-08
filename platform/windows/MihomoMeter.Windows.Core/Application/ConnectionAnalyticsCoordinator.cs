using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public sealed partial class ConnectionAnalyticsCoordinator :
    IConnectionAnalyticsRecorder,
    IConnectionAnalyticsHistoryClearing,
    IAsyncDisposable
{
    public static readonly TimeSpan DefaultFlushInterval = TimeSpan.FromSeconds(10);
    public const int DefaultMaximumPairCountPerDay = 5_000;

    private readonly IConnectionAnalyticsLedger _ledger;
    private readonly IProxyDailyTrafficProvider? _proxyDailyTraffic;
    private readonly TimeProvider _timeProvider;
    private readonly TimeZoneInfo _timeZone;
    private readonly TimeSpan _flushInterval;
    private readonly int _maximumPairCountPerDay;
    private readonly SemaphoreSlim _operationGate = new(1, 1);
    private readonly Dictionary<ConnectionAttributionStorageKey, TrafficBytes> _pending = [];
    private ConnectionAnalyticsState _currentState = ConnectionAnalyticsState.Loading;
    private CancellationTokenSource? _flushSource;
    private Task? _flushTask;
    private bool _disposed;

    public ConnectionAnalyticsCoordinator(
        IConnectionAnalyticsLedger ledger,
        IProxyDailyTrafficProvider? proxyDailyTraffic = null,
        TimeProvider? timeProvider = null,
        TimeZoneInfo? timeZone = null,
        TimeSpan? flushInterval = null,
        int maximumPairCountPerDay = DefaultMaximumPairCountPerDay)
    {
        ArgumentNullException.ThrowIfNull(ledger);
        if (maximumPairCountPerDay <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(maximumPairCountPerDay));
        }

        var selectedFlushInterval = flushInterval ?? DefaultFlushInterval;
        if (selectedFlushInterval <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(flushInterval));
        }

        _ledger = ledger;
        _proxyDailyTraffic = proxyDailyTraffic;
        _timeProvider = timeProvider ?? TimeProvider.System;
        _timeZone = timeZone ?? TimeZoneInfo.Local;
        _flushInterval = selectedFlushInterval;
        _maximumPairCountPerDay = maximumPairCountPerDay;
    }

    public event Action<ConnectionAnalyticsState>? StateChanged;

    public ConnectionAnalyticsState CurrentState => _currentState;

    public async Task PrepareAsync(CancellationToken cancellationToken = default)
    {
        await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_disposed)
            {
                return;
            }

            var snapshot = await _ledger.PrepareAsync(
                _timeZone,
                _timeProvider.GetUtcNow(),
                cancellationToken).ConfigureAwait(false);
            await PublishAvailableSnapshotAsync(
                snapshot,
                _currentState.SelectedLocalDay,
                cancellationToken).ConfigureAwait(false);
            if (_pending.Count > 0 && snapshot.IsHistoryEnabled)
            {
                ScheduleFlushLocked();
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            PublishUnavailable(exception);
        }
        finally
        {
            _operationGate.Release();
        }
    }

    public async Task RefreshAsync(CancellationToken cancellationToken = default)
    {
        await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_disposed)
            {
                return;
            }

            if (!await FlushPendingCoreAsync(
                cancellationToken,
                publishSnapshot: false).ConfigureAwait(false))
            {
                return;
            }

            var snapshot = await _ledger.PrepareAsync(
                _timeZone,
                _timeProvider.GetUtcNow(),
                cancellationToken).ConfigureAwait(false);
            await PublishAvailableSnapshotAsync(
                snapshot,
                _currentState.SelectedLocalDay,
                cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            PublishUnavailable(exception);
        }
        finally
        {
            _operationGate.Release();
        }
    }

    public async Task SetHistoryEnabledAsync(
        bool isEnabled,
        CancellationToken cancellationToken = default)
    {
        await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_disposed
                || _currentState.Availability != ConnectionAnalyticsAvailability.Available
                || isEnabled == _currentState.Snapshot.IsHistoryEnabled)
            {
                return;
            }

            if (!isEnabled
                && !await FlushPendingCoreAsync(
                    cancellationToken,
                    publishSnapshot: false).ConfigureAwait(false))
            {
                return;
            }

            var snapshot = await _ledger.SetHistoryEnabledAsync(
                isEnabled,
                _timeZone,
                _timeProvider.GetUtcNow(),
                cancellationToken).ConfigureAwait(false);
            if (!isEnabled)
            {
                _ = CancelScheduledFlushLocked();
            }
            await PublishAvailableSnapshotAsync(
                snapshot,
                _currentState.SelectedLocalDay,
                cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            PublishUnavailable(exception);
        }
        finally
        {
            _operationGate.Release();
        }
    }

    public async Task SelectDayAsync(
        string localDay,
        CancellationToken cancellationToken = default)
    {
        await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_disposed
                || _currentState.Availability != ConnectionAnalyticsAvailability.Available
                || !_currentState.Snapshot.RecentDays.Any(day =>
                    string.Equals(day.LocalDay, localDay, StringComparison.Ordinal)))
            {
                return;
            }

            if (!await FlushPendingCoreAsync(
                cancellationToken,
                publishSnapshot: false).ConfigureAwait(false))
            {
                return;
            }

            await PublishAvailableSnapshotAsync(
                _currentState.Snapshot,
                localDay,
                cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            PublishUnavailable(exception);
        }
        finally
        {
            _operationGate.Release();
        }
    }

    private async Task PublishAvailableSnapshotAsync(
        ConnectionAnalyticsLedgerSnapshot snapshot,
        string? preferredLocalDay,
        CancellationToken cancellationToken)
    {
        var selectedLocalDay = snapshot.RecentDays.Any(day =>
            string.Equals(day.LocalDay, preferredLocalDay, StringComparison.Ordinal))
                ? preferredLocalDay
                : snapshot.RecentDays.LastOrDefault()?.LocalDay;
        var records = selectedLocalDay is null
            ? Array.Empty<ConnectionAttributionRecord>()
            : await _ledger.RecordsAsync(selectedLocalDay, cancellationToken).ConfigureAwait(false);
        ConnectionAnalyticsRecordingCoverage? coverage = null;
        if (selectedLocalDay is not null && _proxyDailyTraffic is not null)
        {
            var attributed = snapshot.RecentDays.First(day =>
                string.Equals(day.LocalDay, selectedLocalDay, StringComparison.Ordinal)).Bytes;
            try
            {
                var coreProxy = await _proxyDailyTraffic.ProxyTrafficAsync(
                    selectedLocalDay,
                    _timeZone,
                    _timeProvider.GetUtcNow(),
                    cancellationToken).ConfigureAwait(false);
                coverage = new ConnectionAnalyticsRecordingCoverage(attributed, coreProxy);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception)
            {
            }
        }

        Publish(new ConnectionAnalyticsState(
            ConnectionAnalyticsAvailability.Available,
            snapshot,
            selectedLocalDay,
            records,
            coverage));
    }

    private void PublishUnavailable(Exception exception)
    {
        _ = CancelScheduledFlushLocked();
        Publish(new ConnectionAnalyticsState(
            ConnectionAnalyticsAvailability.Unavailable,
            _currentState.Snapshot,
            _currentState.SelectedLocalDay,
            _currentState.SelectedRecords,
            null,
            exception.Message));
    }

    private void Publish(ConnectionAnalyticsState state)
    {
        _currentState = state;
        StateChanged?.Invoke(state);
    }
}
