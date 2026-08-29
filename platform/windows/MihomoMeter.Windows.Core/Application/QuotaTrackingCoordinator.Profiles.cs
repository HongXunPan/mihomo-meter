using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public sealed partial class QuotaTrackingCoordinator
{
    public Task SetProfileDirectoryAsync(
        string directoryPath,
        CancellationToken cancellationToken = default)
    {
        return ExecuteOperationAsync(async () =>
        {
            var fullPath = Path.GetFullPath(directoryPath);
            var catalog = _catalogReader.Read(fullPath);
            await _directoryStore.SaveAsync(fullPath, cancellationToken).ConfigureAwait(false);
            _profileDirectoryPath = fullPath;
            _catalog = catalog;
            _directoryObserver.Start(fullPath);
            await ReconcileCatalogCoreAsync(cancellationToken).ConfigureAwait(false);
            _message = catalog.Profiles.Count == 0
                ? "所选目录没有可追踪的远程 Profile。"
                : null;
            Publish(QuotaAvailability.Available);
        }, cancellationToken);
    }

    public Task ClearProfileDirectoryAsync(CancellationToken cancellationToken = default)
    {
        return ExecuteOperationAsync(async () =>
        {
            _directoryObserver.Stop();
            await _directoryStore.ClearAsync(cancellationToken).ConfigureAwait(false);
            _profileDirectoryPath = null;
            _catalog = ClashProfileCatalog.Empty;
            _message = "Profile 目录访问已停止，既有配额历史已保留。";
            Publish(QuotaAvailability.Available);
        }, cancellationToken);
    }

    public Task SetProfileTrackingAsync(
        string profileUid,
        bool enabled,
        int refreshIntervalMinutes = 360,
        CancellationToken cancellationToken = default)
    {
        return ExecuteOperationAsync(async () =>
        {
            var profile = _catalog.Profiles.FirstOrDefault(item =>
                string.Equals(item.Uid, profileUid, StringComparison.Ordinal))
                ?? throw new ProfileDirectoryException("未找到指定 Profile。");
            var existing = ProfileSubscription(profile.Uid);
            var now = _timeProvider.GetUtcNow();
            if (!enabled)
            {
                if (existing is not null)
                {
                    _ledgerSnapshot = await _ledger
                        .SetSubscriptionStatusAsync(
                            existing.Id,
                            SubscriptionTrackingStatus.Paused,
                            now,
                            cancellationToken)
                        .ConfigureAwait(false);
                }

                _message = null;
                Publish(QuotaAvailability.Available);
                return;
            }

            var fingerprint = await _fingerprinter
                .FingerprintAsync(profile.SubscriptionUri, cancellationToken)
                .ConfigureAwait(false);
            var status = profile.SupportsActiveQuery
                ? SubscriptionTrackingStatus.Active
                : SubscriptionTrackingStatus.Unsupported;
            var subscription = new TrackedSubscription(
                existing?.Id ?? Guid.NewGuid(),
                profile.Name,
                SubscriptionIdentityMode.ClashProfile,
                profile.Uid,
                fingerprint,
                refreshIntervalMinutes,
                status,
                existing?.CreatedAt ?? now,
                now);
            _ledgerSnapshot = await _ledger
                .UpsertSubscriptionAsync(subscription, now, cancellationToken)
                .ConfigureAwait(false);
            _message = profile.SupportsActiveQuery
                ? null
                : "该 Profile 不是 HTTPS 订阅，已标记为不支持主动查询。";
            Publish(QuotaAvailability.Available);
        }, cancellationToken);
    }

    public Task SetProfileRefreshIntervalAsync(
        Guid subscriptionId,
        int refreshIntervalMinutes,
        CancellationToken cancellationToken = default)
    {
        return ExecuteOperationAsync(async () =>
        {
            var existing = ProfileAnalyses()
                .Select(item => item.Subscription)
                .FirstOrDefault(item => item.Id == subscriptionId)
                ?? throw new QuotaDomainException("未找到指定订阅。");
            var now = _timeProvider.GetUtcNow();
            var updated = new TrackedSubscription(
                existing.Id,
                existing.Name,
                existing.IdentityMode,
                existing.ClashProfileUid,
                existing.UrlFingerprint,
                refreshIntervalMinutes,
                existing.Status,
                existing.CreatedAt,
                now);
            _ledgerSnapshot = await _ledger
                .UpsertSubscriptionAsync(updated, now, cancellationToken)
                .ConfigureAwait(false);
            _message = null;
            Publish(QuotaAvailability.Available);
        }, cancellationToken);
    }

    public Task ConfirmCycleAsync(
        Guid cycleId,
        CancellationToken cancellationToken = default)
    {
        return ExecuteOperationAsync(async () =>
        {
            var now = _timeProvider.GetUtcNow();
            _ledgerSnapshot = await _ledger
                .ConfirmCycleAsync(cycleId, now, cancellationToken)
                .ConfigureAwait(false);
            _message = null;
            Publish(QuotaAvailability.Available);
        }, cancellationToken);
    }

    public async Task ClearQuotaDataAsync(CancellationToken cancellationToken = default)
    {
        await ExecuteOperationAsync(async () =>
        {
            await _queryGate.RunAsync(async () =>
            {
                var now = _timeProvider.GetUtcNow();
                _ledgerSnapshot = await _ledger
                    .ResetAsync(now, cancellationToken)
                    .ConfigureAwait(false);
                _runtimeSourceKey = null;
                _message = "订阅配额数据已清空，Controller 与 Profile 目录设置已保留。";
                Publish(QuotaAvailability.Available);
            }, cancellationToken).ConfigureAwait(false);
        }, cancellationToken).ConfigureAwait(false);
    }

    private async Task RefreshCatalogCoreAsync(CancellationToken cancellationToken)
    {
        if (_profileDirectoryPath is null)
        {
            _catalog = ClashProfileCatalog.Empty;
            return;
        }

        _catalog = _catalogReader.Read(_profileDirectoryPath);
        await ReconcileCatalogCoreAsync(cancellationToken).ConfigureAwait(false);
    }

    private async Task ReconcileCatalogCoreAsync(CancellationToken cancellationToken)
    {
        var now = _timeProvider.GetUtcNow();
        foreach (var analysis in ProfileAnalyses())
        {
            var existing = analysis.Subscription;
            var profile = _catalog.Profiles.FirstOrDefault(item =>
                string.Equals(item.Uid, existing.ClashProfileUid, StringComparison.Ordinal));
            if (profile is null)
            {
                if (existing.Status is SubscriptionTrackingStatus.Active
                    or SubscriptionTrackingStatus.Paused)
                {
                    _ledgerSnapshot = await _ledger
                        .SetSubscriptionStatusAsync(
                            existing.Id,
                            SubscriptionTrackingStatus.Unsupported,
                            now,
                            cancellationToken)
                        .ConfigureAwait(false);
                }

                continue;
            }

            var fingerprint = await _fingerprinter
                .FingerprintAsync(profile.SubscriptionUri, cancellationToken)
                .ConfigureAwait(false);
            var status = existing.Status switch
            {
                SubscriptionTrackingStatus.Archived => SubscriptionTrackingStatus.Archived,
                _ when !profile.SupportsActiveQuery => SubscriptionTrackingStatus.Unsupported,
                SubscriptionTrackingStatus.Unsupported => SubscriptionTrackingStatus.Active,
                _ => existing.Status,
            };
            if (!string.Equals(existing.Name, profile.Name, StringComparison.Ordinal)
                || !string.Equals(
                    existing.UrlFingerprint,
                    fingerprint,
                    StringComparison.Ordinal)
                || existing.Status != status)
            {
                var updated = new TrackedSubscription(
                    existing.Id,
                    profile.Name,
                    existing.IdentityMode,
                    existing.ClashProfileUid,
                    fingerprint,
                    existing.RefreshIntervalMinutes,
                    status,
                    existing.CreatedAt,
                    now);
                _ledgerSnapshot = await _ledger
                    .UpsertSubscriptionAsync(updated, now, cancellationToken)
                    .ConfigureAwait(false);
            }
        }
    }

    private IEnumerable<SubscriptionQuotaAnalysis> ProfileAnalyses()
    {
        return _ledgerSnapshot.Subscriptions.Where(item =>
            item.Subscription.IdentityMode == SubscriptionIdentityMode.ClashProfile);
    }

    private TrackedSubscription? ProfileSubscription(string uid)
    {
        return ProfileAnalyses()
            .Select(item => item.Subscription)
            .FirstOrDefault(item => string.Equals(
                item.ClashProfileUid,
                uid,
                StringComparison.Ordinal));
    }

    private void DirectoryObserver_Changed()
    {
        _ = ExecuteOperationAsync(
            () => ReloadCatalogAfterObservationAsync(restartObserver: false),
            CancellationToken.None);
    }

    private void DirectoryObserver_ObservationFailed()
    {
        _ = ExecuteOperationAsync(
            () => ReloadCatalogAfterObservationAsync(restartObserver: true),
            CancellationToken.None);
    }

    private async Task ReloadCatalogAfterObservationAsync(bool restartObserver)
    {
        try
        {
            await RefreshCatalogCoreAsync(CancellationToken.None).ConfigureAwait(false);
            _message = null;
        }
        catch (ProfileDirectoryException exception)
        {
            _catalog = ClashProfileCatalog.Empty;
            _message = exception.Message;
        }

        if (restartObserver && _profileDirectoryPath is string directoryPath)
        {
            try
            {
                _directoryObserver.Start(directoryPath);
            }
            catch (Exception exception) when (
                exception is IOException
                    or UnauthorizedAccessException
                    or ArgumentException)
            {
                _message = "Profile 目录观察无法恢复，请重新选择目录。";
            }
        }

        Publish(QuotaAvailability.Available);
    }
}
