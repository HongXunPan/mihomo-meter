using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public sealed partial class QuotaTrackingCoordinator
{
    public Task RefreshProfileAsync(
        Guid subscriptionId,
        CancellationToken cancellationToken = default)
    {
        return ExecuteOperationAsync(
            () => QueryProfileCoreAsync(
                subscriptionId,
                ProfileQuotaQueryTrigger.Manual,
                cancellationToken),
            cancellationToken);
    }

    public Task RefreshAllProfilesAsync(CancellationToken cancellationToken = default)
    {
        return ExecuteOperationAsync(async () =>
        {
            var ids = ActiveProfileAnalyses()
                .Select(item => item.Subscription.Id)
                .ToArray();
            foreach (var id in ids)
            {
                try
                {
                    await QueryProfileCoreAsync(
                        id,
                        ProfileQuotaQueryTrigger.Manual,
                        cancellationToken).ConfigureAwait(false);
                }
                catch (Exception exception) when (
                    exception is ActiveQuotaQueryException
                        or QuotaDomainException
                        or ProfileDirectoryException)
                {
                    _message = SafeMessage(exception);
                    Publish(QuotaAvailability.Available);
                }
            }
        }, cancellationToken);
    }

    private async Task RunQueryScheduleAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            await ExecuteDueQueriesAsync(cancellationToken).ConfigureAwait(false);
            await Task.Delay(
                QueryScheduleInterval,
                _timeProvider,
                cancellationToken).ConfigureAwait(false);
        }
    }

    private async Task ExecuteDueQueriesAsync(CancellationToken cancellationToken)
    {
        if (_runtimeConfiguration?.Proxy is null)
        {
            return;
        }

        var now = _timeProvider.GetUtcNow();
        var dueIds = ActiveProfileAnalyses()
            .Where(item => _schedulePolicy.DueDate(
                item.Subscription,
                item.QueryState,
                now) <= now)
            .Select(item => item.Subscription.Id)
            .ToArray();
        foreach (var id in dueIds)
        {
            await ExecuteOperationAsync(
                () => QueryProfileCoreAsync(
                    id,
                    ProfileQuotaQueryTrigger.Automatic,
                    cancellationToken),
                cancellationToken).ConfigureAwait(false);
        }
    }

    private async Task QueryProfileCoreAsync(
        Guid subscriptionId,
        ProfileQuotaQueryTrigger trigger,
        CancellationToken cancellationToken)
    {
        var analysis = ProfileAnalyses().FirstOrDefault(item =>
            item.Subscription.Id == subscriptionId)
            ?? throw new QuotaDomainException("未找到指定订阅。");
        var subscription = analysis.Subscription;
        if (subscription.Status != SubscriptionTrackingStatus.Active)
        {
            throw new QuotaDomainException("指定订阅当前未启用追踪。");
        }

        var now = _timeProvider.GetUtcNow();
        if (trigger == ProfileQuotaQueryTrigger.Manual
            && !_schedulePolicy.CanRefreshManually(analysis.QueryState, now))
        {
            throw new QuotaDomainException("手动查询仍在 60 秒冷却期内。");
        }

        var profile = _catalog.Profiles.FirstOrDefault(item => string.Equals(
            item.Uid,
            subscription.ClashProfileUid,
            StringComparison.Ordinal))
            ?? throw new ProfileDirectoryException("Profile 已不存在，请重新核对目录。");
        if (!profile.SupportsActiveQuery)
        {
            throw new ActiveQuotaQueryException(
                ActiveQuotaQueryFailureCategory.InsecureUrl);
        }

        using var querySource = CreateNetworkQuerySource(cancellationToken);
        var queryToken = querySource.Token;
        await _queryGate.RunAsync(async () =>
        {
            _message = $"正在查询 {subscription.Name}。";
            Publish(QuotaAvailability.Available);
            try
            {
                var proxy = _runtimeConfiguration?.Proxy
                    ?? throw new ActiveQuotaQueryException(
                        ActiveQuotaQueryFailureCategory.NoProxy);
                var userAgent = _runtimeConfiguration?.UserAgent ?? "clash.meta";
                var result = await _activeQueryClient
                    .QueryAsync(
                        profile.SubscriptionUri,
                        proxy,
                        userAgent,
                        queryToken)
                    .ConfigureAwait(false);
                var completedAt = _timeProvider.GetUtcNow();
                _ledgerSnapshot = await _ledger
                    .RecordAsync(
                        new QuotaObservation(
                            subscription.Id,
                            completedAt,
                            null,
                            QuotaObservationSource.MeterActiveQuery,
                            result.Traffic,
                            result.ExpireAt),
                        completedAt,
                        queryToken)
                    .ConfigureAwait(false);
                _ledgerSnapshot = await _ledger
                    .SaveQueryStateAsync(
                        _schedulePolicy.Success(
                            subscription,
                            completedAt,
                            RandomJitter()),
                        completedAt,
                        queryToken)
                    .ConfigureAwait(false);
                _message = $"{subscription.Name} 配额已更新。";
                Publish(QuotaAvailability.Available);
            }
            catch (ActiveQuotaQueryException exception)
            {
                var failedAt = _timeProvider.GetUtcNow();
                _ledgerSnapshot = await _ledger
                    .SaveQueryStateAsync(
                        _schedulePolicy.Failure(
                            subscription,
                            analysis.QueryState,
                            trigger,
                            failedAt,
                            RandomJitter(),
                            FailureCategory(exception)),
                        failedAt,
                        queryToken)
                    .ConfigureAwait(false);
                _message = exception.Message;
                Publish(QuotaAvailability.Available);
                throw;
            }
        }, queryToken).ConfigureAwait(false);
    }

    private IEnumerable<SubscriptionQuotaAnalysis> ActiveProfileAnalyses()
    {
        return ProfileAnalyses().Where(item =>
            item.Subscription.Status == SubscriptionTrackingStatus.Active);
    }

    private static TimeSpan RandomJitter()
    {
        return TimeSpan.FromSeconds(Random.Shared.NextDouble() * 30);
    }

    private static string FailureCategory(ActiveQuotaQueryException exception)
    {
        return exception.Category switch
        {
            ActiveQuotaQueryFailureCategory.Timeout => "timeout",
            ActiveQuotaQueryFailureCategory.Network => "network",
            ActiveQuotaQueryFailureCategory.HttpStatus => "http_status",
            ActiveQuotaQueryFailureCategory.MissingHeader => "missing_header",
            ActiveQuotaQueryFailureCategory.InvalidHeader => "invalid_header",
            ActiveQuotaQueryFailureCategory.InsecureRedirect => "insecure_redirect",
            ActiveQuotaQueryFailureCategory.InsecureUrl => "insecure_url",
            ActiveQuotaQueryFailureCategory.NoProxy => "no_proxy",
            _ => "query_failed",
        };
    }
}
