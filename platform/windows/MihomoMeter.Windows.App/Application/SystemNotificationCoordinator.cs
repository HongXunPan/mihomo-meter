using MihomoMeter.Windows.App.Infrastructure.Notifications;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Application;

internal sealed class SystemNotificationCoordinator : IAsyncDisposable
{
    private const string QuotaKeyPrefix = "quota|";
    private readonly object _sync = new();
    private readonly QuotaTrackingCoordinator _quota;
    private readonly TrafficMonitoringCoordinator _traffic;
    private readonly WindowsSystemNotificationService _service;
    private readonly ISystemNotificationPreferencesStore _store;
    private readonly TimeProvider _timeProvider;
    private readonly SemaphoreSlim _persistenceGate = new(1, 1);
    private SystemNotificationPreferences _preferences = SystemNotificationPreferences.Disabled;
    private readonly HashSet<string> _inFlightKeys = new(StringComparer.Ordinal);
    private DateTimeOffset? _disconnectedSince;
    private ITimer? _disconnectTimer;
    private string? _errorMessage;
    private bool _initialized;
    private bool _disposed;

    public SystemNotificationCoordinator(
        QuotaTrackingCoordinator quota,
        TrafficMonitoringCoordinator traffic,
        WindowsSystemNotificationService service,
        ISystemNotificationPreferencesStore store,
        TimeProvider? timeProvider = null)
    {
        _quota = quota;
        _traffic = traffic;
        _service = service;
        _store = store;
        _timeProvider = timeProvider ?? TimeProvider.System;
    }

    public bool IsEnabled
    {
        get
        {
            lock (_sync)
            {
                return _preferences.Enabled;
            }
        }
    }

    public bool DisconnectAlertsEnabled
    {
        get
        {
            lock (_sync)
            {
                return _preferences.DisconnectAlertsEnabled;
            }
        }
    }

    public bool IsSystemAvailable => _service.IsAvailable;

    public string? ErrorMessage
    {
        get
        {
            lock (_sync)
            {
                return _errorMessage;
            }
        }
    }

    public string StatusMessage
    {
        get
        {
            if (!IsEnabled)
            {
                return "系统通知默认关闭；开启后才会投递通用提醒。";
            }
            return IsSystemAvailable
                ? "系统通知已开启；锁屏内容只使用通用描述。"
                : "Windows 已禁止通知或通知服务不可用，请检查系统通知设置。";
        }
    }

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        if (_initialized || _disposed)
        {
            return;
        }

        try
        {
            var preferences = await _store
                .LoadAsync(cancellationToken)
                .ConfigureAwait(false);
            lock (_sync)
            {
                _preferences = Clone(preferences);
                _errorMessage = null;
            }
        }
        catch (SystemNotificationPreferencesStorageException)
        {
            lock (_sync)
            {
                _preferences = SystemNotificationPreferences.Disabled;
                _errorMessage = "系统通知设置无法读取，已按默认关闭处理。";
            }
        }

        _quota.StateChanged += Quota_StateChanged;
        _traffic.SnapshotChanged += Traffic_SnapshotChanged;
        _initialized = true;
        EvaluateQuota(_quota.CurrentState);
    }

    public void SetEnabled(bool enabled)
    {
        lock (_sync)
        {
            _preferences = _preferences with { Enabled = enabled };
            _errorMessage = null;
        }
        QueuePersistence();
        if (enabled)
        {
            EvaluateQuota(_quota.CurrentState);
            EvaluateDisconnect();
        }
    }

    public void SetDisconnectAlertsEnabled(bool enabled)
    {
        lock (_sync)
        {
            _preferences = _preferences with { DisconnectAlertsEnabled = enabled };
            _errorMessage = null;
        }
        QueuePersistence();
        if (enabled)
        {
            EvaluateDisconnect();
        }
    }

    public void RefreshSystemStatus()
    {
        _ = IsSystemAvailable;
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _quota.StateChanged -= Quota_StateChanged;
        _traffic.SnapshotChanged -= Traffic_SnapshotChanged;
        lock (_sync)
        {
            _disconnectTimer?.Dispose();
            _disconnectTimer = null;
        }
        await _persistenceGate.WaitAsync().ConfigureAwait(false);
        _persistenceGate.Release();
        _service.Dispose();
    }

    private void Quota_StateChanged(QuotaTrackingState state)
    {
        EvaluateQuota(state);
    }

    private void EvaluateQuota(QuotaTrackingState state)
    {
        var deliveries = QuotaSystemNotificationPolicy.Deliveries(
            state.Ledger.Subscriptions,
            _timeProvider.GetUtcNow());
        var activeKeys = deliveries
            .Select(item => item.DeduplicationKey)
            .ToHashSet(StringComparer.Ordinal);
        var changed = false;
        lock (_sync)
        {
            var delivered = _preferences.DeliveredKeys.ToHashSet(StringComparer.Ordinal);
            changed = delivered.RemoveWhere(key =>
                key.StartsWith(QuotaKeyPrefix, StringComparison.Ordinal)
                && !activeKeys.Contains(key)) > 0;
            if (changed)
            {
                _preferences = _preferences with { DeliveredKeys = delivered };
            }
        }
        if (changed)
        {
            QueuePersistence();
        }
        foreach (var delivery in deliveries)
        {
            TryDeliver(delivery, requiresDisconnectPreference: false);
        }
    }

    private void Traffic_SnapshotChanged(TrafficMonitorSnapshot snapshot)
    {
        var shouldTrack = _traffic.IsConnectionExpected
            && _traffic.HasValidatedConfiguration
            && _traffic.IsSystemEnvironmentAvailable
            && snapshot.ConnectionState != MonitorConnectionState.Connected;
        var shouldPersist = false;
        lock (_sync)
        {
            if (!shouldTrack)
            {
                _disconnectedSince = null;
                _disconnectTimer?.Dispose();
                _disconnectTimer = null;
                var delivered = _preferences.DeliveredKeys.ToHashSet(StringComparer.Ordinal);
                shouldPersist = delivered.Remove(
                    ConnectionSystemNotificationPolicy.DeduplicationKey);
                if (shouldPersist)
                {
                    _preferences = _preferences with { DeliveredKeys = delivered };
                }
            }
            else
            {
                _disconnectedSince ??= _timeProvider.GetUtcNow();
                ScheduleDisconnectTimerLocked();
            }
        }
        if (shouldPersist)
        {
            QueuePersistence();
        }
    }

    private void ScheduleDisconnectTimerLocked()
    {
        _disconnectTimer?.Dispose();
        var elapsed = _disconnectedSince is DateTimeOffset startedAt
            ? _timeProvider.GetUtcNow() - startedAt
            : TimeSpan.Zero;
        var delay = ConnectionSystemNotificationPolicy.SustainedDisconnectionInterval - elapsed;
        if (delay < TimeSpan.Zero)
        {
            delay = TimeSpan.Zero;
        }
        _disconnectTimer = _timeProvider.CreateTimer(
            _ => EvaluateDisconnect(),
            null,
            delay,
            Timeout.InfiniteTimeSpan);
    }

    private void EvaluateDisconnect()
    {
        DateTimeOffset? disconnectedSince;
        lock (_sync)
        {
            disconnectedSince = _disconnectedSince;
        }
        if (!_traffic.IsConnectionExpected
            || !_traffic.HasValidatedConfiguration
            || !_traffic.IsSystemEnvironmentAvailable
            || !ConnectionSystemNotificationPolicy.ShouldNotify(
                disconnectedSince,
                _timeProvider.GetUtcNow()))
        {
            return;
        }
        TryDeliver(
            ConnectionSystemNotificationPolicy.Delivery,
            requiresDisconnectPreference: true);
    }

    private void TryDeliver(
        SystemNotificationDelivery delivery,
        bool requiresDisconnectPreference)
    {
        lock (_sync)
        {
            if (!_preferences.Enabled
                || (requiresDisconnectPreference && !_preferences.DisconnectAlertsEnabled)
                || _preferences.DeliveredKeys.Contains(delivery.DeduplicationKey)
                || !_inFlightKeys.Add(delivery.DeduplicationKey))
            {
                return;
            }
        }

        var succeeded = _service.TryShow(delivery);
        lock (_sync)
        {
            _inFlightKeys.Remove(delivery.DeduplicationKey);
            if (succeeded)
            {
                var delivered = _preferences.DeliveredKeys.ToHashSet(StringComparer.Ordinal);
                delivered.Add(delivery.DeduplicationKey);
                _preferences = _preferences with { DeliveredKeys = delivered };
            }
            else
            {
                _errorMessage = "系统通知投递失败；监控和配额采集不受影响。";
            }
        }
        if (succeeded)
        {
            QueuePersistence();
        }
    }

    private void QueuePersistence()
    {
        _ = PersistCurrentAsync();
    }

    private async Task PersistCurrentAsync()
    {
        try
        {
            await _persistenceGate.WaitAsync().ConfigureAwait(false);
            SystemNotificationPreferences snapshot;
            lock (_sync)
            {
                snapshot = Clone(_preferences);
            }
            await _store.SaveAsync(snapshot, CancellationToken.None).ConfigureAwait(false);
        }
        catch (SystemNotificationPreferencesStorageException)
        {
            lock (_sync)
            {
                _errorMessage = "系统通知设置无法保存；本次运行仍按当前选择处理。";
            }
        }
        finally
        {
            _persistenceGate.Release();
        }
    }

    private static SystemNotificationPreferences Clone(
        SystemNotificationPreferences preferences)
    {
        return preferences with
        {
            DeliveredKeys = preferences.DeliveredKeys.ToHashSet(StringComparer.Ordinal),
        };
    }
}
