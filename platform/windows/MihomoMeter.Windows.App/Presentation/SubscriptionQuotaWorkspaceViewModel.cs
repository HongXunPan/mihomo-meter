using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class SubscriptionQuotaWorkspaceViewModel : INotifyPropertyChanged
{
    private static readonly IReadOnlyList<QuotaWindowOption> Windows =
    [
        new(QuotaTrendWindow.Day, "24 小时"),
        new(QuotaTrendWindow.Week, "7 天"),
        new(QuotaTrendWindow.Month, "30 天"),
        new(QuotaTrendWindow.Year, "12 月"),
    ];

    private readonly DispatcherQueue _dispatcherQueue;
    private readonly QuotaTrackingCoordinator _coordinator;
    private readonly ObservableCollection<SubscriptionQuotaCardViewModel> _cards = [];
    private readonly ObservableCollection<ProfileTrackingOptionViewModel> _profiles = [];
    private QuotaTrackingState _state;
    private QuotaWindowOption _selectedWindow = Windows[1];

    internal SubscriptionQuotaWorkspaceViewModel(
        DispatcherQueue dispatcherQueue,
        QuotaTrackingCoordinator coordinator)
    {
        _dispatcherQueue = dispatcherQueue;
        _coordinator = coordinator;
        _state = coordinator.CurrentState;
        _coordinator.StateChanged += Coordinator_StateChanged;
        ApplyState(_state);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public IReadOnlyList<QuotaWindowOption> WindowOptions => Windows;

    public QuotaWindowOption SelectedWindow
    {
        get => _selectedWindow;
        set
        {
            if (value is null || Equals(_selectedWindow, value))
            {
                return;
            }

            _selectedWindow = value;
            OnPropertyChanged();
            UpdateCards();
        }
    }

    public ObservableCollection<SubscriptionQuotaCardViewModel> Cards => _cards;

    public ObservableCollection<ProfileTrackingOptionViewModel> Profiles => _profiles;

    public Visibility LoadingVisibility => _state.Availability == QuotaAvailability.Loading
        ? Visibility.Visible
        : Visibility.Collapsed;

    public Visibility ContentVisibility => _state.Availability == QuotaAvailability.Loading
        ? Visibility.Collapsed
        : Visibility.Visible;

    public Visibility EmptyVisibility => Cards.Count == 0
        ? Visibility.Visible
        : Visibility.Collapsed;

    public Visibility CardsVisibility => Cards.Count == 0
        ? Visibility.Collapsed
        : Visibility.Visible;

    public bool IsNoticeOpen => !string.IsNullOrWhiteSpace(_state.Message)
        || _state.Availability == QuotaAvailability.Unavailable;

    public InfoBarSeverity NoticeSeverity => _state.Availability == QuotaAvailability.Unavailable
        ? InfoBarSeverity.Warning
        : InfoBarSeverity.Informational;

    public string NoticeTitle => _state.Availability == QuotaAvailability.Unavailable
        ? "订阅配额暂不可用"
        : "订阅配额提示";

    public string NoticeMessage => _state.Message
        ?? "配额来源失败会保留最近有效历史，不会写入零值。";

    public string DirectoryStatusText => _state.ProfileDirectoryPath is null
        ? "未选择 Profile 目录；可先使用当前运行订阅轻量模式。"
        : $"已读取 {_state.Catalog.Profiles.Count} 个远程 Profile"
            + (_state.Catalog.CurrentProfile is null ? string.Empty : " · 已识别当前 Profile");

    public string RuntimeStatusText => _state.RuntimeStatus switch
    {
        RuntimeQuotaObservationStatus.ControllerUnavailable => "连接 Mihomo 后检查当前运行订阅。",
        RuntimeQuotaObservationStatus.Checking => "正在检查当前运行订阅配额。",
        RuntimeQuotaObservationStatus.NoCandidate => "当前配置没有有效配额候选。",
        RuntimeQuotaObservationStatus.SingleCandidate => "已找到唯一配额候选，可以启用轻量追踪。",
        RuntimeQuotaObservationStatus.MultipleCandidates =>
            $"发现 {_state.RuntimeCandidateCount} 个候选，轻量模式已暂停。",
        _ => "当前运行订阅检查失败，已保留历史。",
    };

    public bool CanEnableRuntime => _state.RuntimeStatus
        == RuntimeQuotaObservationStatus.SingleCandidate
        && RuntimeSubscription()?.Status != SubscriptionTrackingStatus.Active
        && !_state.OperationInProgress;

    public bool CanPauseRuntime => RuntimeSubscription()?.Status
        == SubscriptionTrackingStatus.Active
        && !_state.OperationInProgress;

    public bool CanRefreshAll => _state.ActiveQueryAvailable
        && _state.Ledger.Subscriptions.Any(item =>
            item.Subscription.IdentityMode == SubscriptionIdentityMode.ClashProfile
            && item.Subscription.Status == SubscriptionTrackingStatus.Active)
        && !_state.OperationInProgress;

    public bool CanClear => _state.Availability == QuotaAvailability.Available
        && !_state.OperationInProgress;

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        await _coordinator.PrepareAsync(cancellationToken);
    }

    public Task SetProfileDirectoryAsync(
        string directoryPath,
        CancellationToken cancellationToken = default)
    {
        return _coordinator.SetProfileDirectoryAsync(directoryPath, cancellationToken);
    }

    public Task ClearProfileDirectoryAsync(CancellationToken cancellationToken = default)
    {
        return _coordinator.ClearProfileDirectoryAsync(cancellationToken);
    }

    public Task EnableRuntimeAsync(CancellationToken cancellationToken = default)
    {
        return _coordinator.EnableRuntimeTrackingAsync(cancellationToken);
    }

    public Task PauseRuntimeAsync(CancellationToken cancellationToken = default)
    {
        return _coordinator.PauseRuntimeTrackingAsync(cancellationToken);
    }

    public Task SetProfileTrackingAsync(
        ProfileTrackingOptionViewModel profile,
        bool enabled,
        CancellationToken cancellationToken = default)
    {
        return _coordinator.SetProfileTrackingAsync(
            profile.Uid,
            enabled,
            profile.RefreshIntervalMinutes,
            cancellationToken);
    }

    public Task SetRefreshIntervalAsync(
        ProfileTrackingOptionViewModel profile,
        CancellationToken cancellationToken = default)
    {
        var subscription = ProfileSubscription(profile.Uid);
        return subscription is null
            || subscription.RefreshIntervalMinutes == profile.RefreshIntervalMinutes
            ? Task.CompletedTask
            : _coordinator.SetProfileRefreshIntervalAsync(
                subscription.Id,
                profile.RefreshIntervalMinutes,
                cancellationToken);
    }

    public Task RefreshProfileAsync(
        Guid subscriptionId,
        CancellationToken cancellationToken = default)
    {
        return _coordinator.RefreshProfileAsync(subscriptionId, cancellationToken);
    }

    public Task RefreshAllAsync(CancellationToken cancellationToken = default)
    {
        return _coordinator.RefreshAllProfilesAsync(cancellationToken);
    }

    public Task ConfirmCycleAsync(
        Guid cycleId,
        CancellationToken cancellationToken = default)
    {
        return _coordinator.ConfirmCycleAsync(cycleId, cancellationToken);
    }

    public Task ClearAsync(CancellationToken cancellationToken = default)
    {
        return _coordinator.ClearQuotaDataAsync(cancellationToken);
    }

    internal void Detach()
    {
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
        _state = state;
        OnPropertyChanged(nameof(LoadingVisibility));
        OnPropertyChanged(nameof(ContentVisibility));
        OnPropertyChanged(nameof(IsNoticeOpen));
        OnPropertyChanged(nameof(NoticeSeverity));
        OnPropertyChanged(nameof(NoticeTitle));
        OnPropertyChanged(nameof(NoticeMessage));
        OnPropertyChanged(nameof(DirectoryStatusText));
        OnPropertyChanged(nameof(RuntimeStatusText));
        OnPropertyChanged(nameof(CanEnableRuntime));
        OnPropertyChanged(nameof(CanPauseRuntime));
        OnPropertyChanged(nameof(CanRefreshAll));
        OnPropertyChanged(nameof(CanClear));
        UpdateProfiles();
        UpdateCards();
    }

    private TrackedSubscription? RuntimeSubscription()
    {
        return _state.Ledger.Subscriptions
            .Select(item => item.Subscription)
            .FirstOrDefault(item =>
                item.IdentityMode == SubscriptionIdentityMode.RuntimeSingle);
    }

    private TrackedSubscription? ProfileSubscription(string uid)
    {
        return _state.Ledger.Subscriptions
            .Select(item => item.Subscription)
            .FirstOrDefault(item => string.Equals(
                item.ClashProfileUid,
                uid,
                StringComparison.Ordinal));
    }

    private void OnPropertyChanged([CallerMemberName] string? name = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
