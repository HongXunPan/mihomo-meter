using System.Collections.ObjectModel;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class SubscriptionQuotaWorkspaceViewModel
{
    private void UpdateCards()
    {
        var now = DateTimeOffset.Now;
        var desired = _state.Ledger.Subscriptions
            .Where(item => item.Subscription.Status != SubscriptionTrackingStatus.Archived)
            .OrderBy(item => item.Subscription.IdentityMode == SubscriptionIdentityMode.RuntimeSingle
                ? 0
                : string.Equals(
                    item.Subscription.ClashProfileUid,
                    _state.Catalog.CurrentUid,
                    StringComparison.Ordinal) ? 1 : 2)
            .Select(item => Card(item, now))
            .ToArray();
        ApplyStableCollection(_cards, desired, item => item.Id);
        OnPropertyChanged(nameof(EmptyVisibility));
        OnPropertyChanged(nameof(CardsVisibility));
    }

    private SubscriptionQuotaCardViewModel Card(
        SubscriptionQuotaAnalysis analysis,
        DateTimeOffset now)
    {
        var subscription = analysis.Subscription;
        var latest = analysis.LatestSnapshot;
        var traffic = latest?.Traffic;
        var percentage = traffic is null
            ? 0
            : (double)traffic.Value.RemainingBytes / traffic.Value.TotalBytes;
        var trendModels = analysis.Trends.ToDictionary(
            item => item.Key,
            item => TrendModel(item.Value));
        var canRefresh = subscription.IdentityMode == SubscriptionIdentityMode.ClashProfile
            && subscription.Status == SubscriptionTrackingStatus.Active
            && _state.ActiveQueryAvailable
            && !_state.OperationInProgress
            && CanRefreshManually(analysis.QueryState, now);
        return new SubscriptionQuotaCardViewModel(
            subscription.Id,
            subscription.Name,
            IdentityText(subscription),
            traffic is null ? "--" : SubscriptionQuotaFormatter.Bytes(traffic.Value.RemainingBytes),
            traffic is null ? "已用 --" : $"已用 {SubscriptionQuotaFormatter.Bytes(traffic.Value.UsedBytes)}",
            traffic is null ? "总量 --" : $"总量 {SubscriptionQuotaFormatter.Bytes(traffic.Value.TotalBytes)}",
            traffic is null ? "--" : $"{percentage:P1}",
            percentage,
            SubscriptionQuotaFormatter.UpdatedAt(latest?.EffectiveAt, now),
            SubscriptionQuotaFormatter.Expiration(latest?.ExpireAt, now),
            SubscriptionQuotaFormatter.Forecast(analysis.Forecast, now),
            StatusText(analysis, now),
            canRefresh,
            subscription.IdentityMode == SubscriptionIdentityMode.ClashProfile
                ? Visibility.Visible
                : Visibility.Collapsed,
            analysis.CurrentCycle is { IsUserConfirmed: false }
                ? Visibility.Visible
                : Visibility.Collapsed,
            analysis.CurrentCycle?.Id,
            trendModels[_selectedWindow.Window],
            analysis.RecentEvents
                .Take(3)
                .Select(item => new QuotaEventSummaryViewModel(
                    EventSymbol(item.Kind),
                    SubscriptionQuotaFormatter.Event(item.Kind),
                    QuotaRelativeTimeFormatter.Format(item.OccurredAt, now)))
                .ToArray(),
            trendModels,
            _selectedWindow);
    }

    private static QuotaTrendChartModel TrendModel(QuotaTrend trend)
    {
        return new QuotaTrendChartModel(
            trend,
            $"本范围新增：下载 {SubscriptionQuotaFormatter.Bytes(trend.RangeUsage.DownloadBytes)}"
                + $" · 上传 {SubscriptionQuotaFormatter.Bytes(trend.RangeUsage.UploadBytes)}"
                + $" · 合计 {SubscriptionQuotaFormatter.Bytes(trend.RangeUsage.TotalBytes)}",
            "当前范围内尚无可绘制的真实快照。");
    }

    private static string EventSymbol(QuotaEventKind kind)
    {
        return kind switch
        {
            QuotaEventKind.UsageReset => "↻",
            QuotaEventKind.TotalIncreased => "+",
            QuotaEventKind.TotalDecreased => "−",
            QuotaEventKind.ExpirationChanged => "◷",
            _ => "•",
        };
    }

    private void UpdateProfiles()
    {
        var desired = _state.Catalog.Profiles.Select(profile =>
        {
            var subscription = ProfileSubscription(profile.Uid);
            var tracked = subscription?.Status == SubscriptionTrackingStatus.Active;
            var interval = subscription?.RefreshIntervalMinutes ?? 360;
            var detail = string.Equals(
                profile.Uid,
                _state.Catalog.CurrentUid,
                StringComparison.Ordinal)
                ? "当前 Profile"
                : "远程 Profile";
            if (!profile.SupportsActiveQuery)
            {
                detail += " · 非 HTTPS，不支持主动查询";
            }

            return new ProfileTrackingOptionViewModel(
                profile.Uid,
                profile.Name,
                detail,
                tracked,
                profile.SupportsActiveQuery,
                interval);
        }).ToArray();
        ApplyStableCollection(_profiles, desired, item => item.Uid);
    }

    private static bool CanRefreshManually(
        ProfileQuotaQueryState? state,
        DateTimeOffset now)
    {
        return state?.LastAttemptAt is not DateTimeOffset last
            || state.LastFailureCategory is "timeout" or "network"
            || now >= last + TimeSpan.FromSeconds(60);
    }

    private static string IdentityText(TrackedSubscription subscription)
    {
        return subscription.IdentityMode == SubscriptionIdentityMode.RuntimeSingle
            ? "轻量模式 · 当前运行订阅"
            : "指定 Profile · 经当前 Mihomo 查询";
    }

    private static string StatusText(
        SubscriptionQuotaAnalysis analysis,
        DateTimeOffset now)
    {
        if (analysis.Subscription.Status == SubscriptionTrackingStatus.Paused)
        {
            return "追踪已暂停，历史仍保留";
        }

        if (analysis.Subscription.Status == SubscriptionTrackingStatus.Unsupported)
        {
            return "当前订阅不支持主动查询";
        }

        return analysis.Subscription.IdentityMode == SubscriptionIdentityMode.RuntimeSingle
            ? "每 5 分钟观察 Mihomo Provider，不主动刷新机场"
            : SubscriptionQuotaFormatter.QueryStatus(analysis.QueryState, now);
    }

    private static void ApplyStableCollection<T, TKey>(
        ObservableCollection<T> target,
        IReadOnlyList<T> desired,
        Func<T, TKey> key)
        where T : class
        where TKey : notnull
    {
        for (var index = 0; index < desired.Count; index += 1)
        {
            var desiredItem = desired[index];
            var existingIndex = -1;
            for (var candidate = 0; candidate < target.Count; candidate += 1)
            {
                if (EqualityComparer<TKey>.Default.Equals(
                    key(target[candidate]),
                    key(desiredItem)))
                {
                    existingIndex = candidate;
                    break;
                }
            }

            if (existingIndex < 0)
            {
                target.Insert(index, desiredItem);
                continue;
            }

            if (existingIndex != index)
            {
                target.Move(existingIndex, index);
            }

            switch (target[index], desiredItem)
            {
                case (SubscriptionQuotaCardViewModel current, SubscriptionQuotaCardViewModel snapshot):
                    current.Apply(snapshot);
                    break;
                case (ProfileTrackingOptionViewModel current, ProfileTrackingOptionViewModel snapshot):
                    current.Apply(snapshot);
                    break;
            }
        }

        while (target.Count > desired.Count)
        {
            target.RemoveAt(target.Count - 1);
        }
    }
}
