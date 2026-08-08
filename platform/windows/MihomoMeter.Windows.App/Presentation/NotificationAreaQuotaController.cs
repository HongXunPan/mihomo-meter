using Microsoft.UI.Dispatching;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

internal sealed record NotificationAreaQuotaItemSnapshot(
    string Name,
    string Summary,
    string Detail);

internal sealed record NotificationAreaQuotaMenuSnapshot(
    string Title,
    string? Notice,
    IReadOnlyList<NotificationAreaQuotaItemSnapshot> Items,
    int AdditionalCount,
    bool CanRefreshAll);

internal sealed class NotificationAreaQuotaController : IDisposable
{
    private const int MaximumItems = 5;
    private readonly DispatcherQueue _dispatcherQueue;
    private readonly QuotaTrackingCoordinator _coordinator;
    private readonly TimeProvider _timeProvider;
    private QuotaTrackingState _state;
    private bool _disposed;

    public NotificationAreaQuotaController(
        DispatcherQueue dispatcherQueue,
        QuotaTrackingCoordinator coordinator,
        TimeProvider? timeProvider = null)
    {
        _dispatcherQueue = dispatcherQueue;
        _coordinator = coordinator;
        _timeProvider = timeProvider ?? TimeProvider.System;
        _state = coordinator.CurrentState;
        _coordinator.StateChanged += Coordinator_StateChanged;
    }

    public NotificationAreaQuotaMenuSnapshot CaptureSnapshot()
    {
        if (!_dispatcherQueue.HasThreadAccess)
        {
            throw new InvalidOperationException("通知区域配额快照只能在界面线程读取。");
        }

        var analyses = _state.Ledger.Subscriptions
            .Where(item => item.Subscription.Status != SubscriptionTrackingStatus.Archived)
            .OrderBy(item => item.Subscription.IdentityMode == SubscriptionIdentityMode.RuntimeSingle
                ? 0
                : 1)
            .ThenBy(item => item.Subscription.Name, StringComparer.CurrentCultureIgnoreCase)
            .ToArray();
        var now = _timeProvider.GetUtcNow();
        var items = analyses.Take(MaximumItems)
            .Select(item => Item(item, now))
            .ToArray();
        var canRefresh = _state.ActiveQueryAvailable
            && !_state.OperationInProgress
            && analyses.Any(item =>
                item.Subscription.IdentityMode == SubscriptionIdentityMode.ClashProfile
                && item.Subscription.Status == SubscriptionTrackingStatus.Active);
        return new NotificationAreaQuotaMenuSnapshot(
            $"订阅余额（{analyses.Length}）",
            Notice(),
            Array.AsReadOnly(items),
            Math.Max(analyses.Length - MaximumItems, 0),
            canRefresh);
    }

    public Task RefreshAllAsync()
    {
        return _disposed || !CaptureSnapshot().CanRefreshAll
            ? Task.CompletedTask
            : _coordinator.RefreshAllProfilesAsync();
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _coordinator.StateChanged -= Coordinator_StateChanged;
    }

    private void Coordinator_StateChanged(QuotaTrackingState state)
    {
        if (_dispatcherQueue.HasThreadAccess)
        {
            ApplyState(state);
            return;
        }

        _ = _dispatcherQueue.TryEnqueue(() => ApplyState(state));
    }

    private void ApplyState(QuotaTrackingState state)
    {
        if (!_disposed)
        {
            _state = state;
        }
    }

    private string? Notice()
    {
        return _state.Availability switch
        {
            QuotaAvailability.Loading => "正在读取订阅配额…",
            QuotaAvailability.Unavailable => _state.Message ?? "订阅配额暂不可用。",
            _ when _state.Ledger.Subscriptions.Count == 0 => "尚未追踪订阅。",
            _ => _state.Message,
        };
    }

    private static NotificationAreaQuotaItemSnapshot Item(
        SubscriptionQuotaAnalysis analysis,
        DateTimeOffset now)
    {
        var latest = analysis.LatestSnapshot;
        var summary = latest is null
            ? "尚无有效配额快照"
            : $"剩余 {SubscriptionQuotaFormatter.Bytes(latest.Traffic.RemainingBytes)}"
                + $" / {SubscriptionQuotaFormatter.Bytes(latest.Traffic.TotalBytes)}";
        var detail = analysis.Subscription.Status switch
        {
            SubscriptionTrackingStatus.Paused => "追踪已暂停",
            SubscriptionTrackingStatus.Unsupported => "不支持主动查询",
            _ => SubscriptionQuotaFormatter.Forecast(analysis.Forecast, now),
        };
        return new NotificationAreaQuotaItemSnapshot(
            analysis.Subscription.Name,
            summary,
            detail);
    }
}
