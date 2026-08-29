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
            var startedAt = _timeProvider.GetTimestamp();
            var configuredProxy = _runtimeConfiguration?.Proxy;
            _diagnosticEventSink.Record(DiagnosticExportEvent.ProfileQuotaQueryStarted(
                _timeProvider.GetUtcNow(),
                TriggerValue(trigger),
                string.Equals(
                    _catalog.CurrentUid,
                    profile.Uid,
                    StringComparison.Ordinal),
                configuredProxy is null ? "unknown" : ProxyKindValue(configuredProxy.Kind),
                _runtimeConfiguration?.UsesConfiguredUserAgent == true
                    ? "mihomo_config"
                    : "mihomo_default"));
            try
            {
                var proxy = configuredProxy
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
                RecordProfileQueryFinished(
                    trigger,
                    "succeeded",
                    startedAt,
                    null,
                    null);
            }
            catch (OperationCanceledException)
            {
                RecordProfileQueryFinished(
                    trigger,
                    "cancelled",
                    startedAt,
                    null,
                    null);
                throw;
            }
            catch (ActiveQuotaQueryException exception)
            {
                var failedAt = _timeProvider.GetUtcNow();
                var failedState = _schedulePolicy.Failure(
                    subscription,
                    analysis.QueryState,
                    trigger,
                    failedAt,
                    RandomJitter(),
                    FailureCategory(exception));
                try
                {
                    _ledgerSnapshot = await _ledger
                        .SaveQueryStateAsync(
                            failedState,
                            failedAt,
                            queryToken)
                        .ConfigureAwait(false);
                }
                catch (Exception)
                {
                    RecordProfileQueryFinished(
                        trigger,
                        "storage_failed",
                        startedAt,
                        null,
                        null);
                    throw;
                }
                _message = exception.Message;
                Publish(QuotaAvailability.Available);
                RecordProfileQueryFinished(
                    trigger,
                    FailureCategory(exception),
                    startedAt,
                    failedState.NextAttemptAt,
                    exception.StatusCode);
                throw;
            }
            catch (Exception)
            {
                RecordProfileQueryFinished(
                    trigger,
                    "storage_failed",
                    startedAt,
                    null,
                    null);
                throw;
            }
        }, queryToken).ConfigureAwait(false);
    }

    private IEnumerable<SubscriptionQuotaAnalysis> ActiveProfileAnalyses()
    {
        return ProfileAnalyses().Where(item =>
            item.Subscription.Status == SubscriptionTrackingStatus.Active
            && _catalog.Profiles.Any(profile =>
                string.Equals(
                    profile.Uid,
                    item.Subscription.ClashProfileUid,
                    StringComparison.Ordinal)
                && profile.SupportsActiveQuery));
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

    private void RecordProfileQueryFinished(
        ProfileQuotaQueryTrigger trigger,
        string outcome,
        long startedAt,
        DateTimeOffset? retryAt,
        int? httpStatus)
    {
        var now = _timeProvider.GetUtcNow();
        var elapsed = _timeProvider.GetElapsedTime(startedAt).TotalMilliseconds;
        var elapsedMilliseconds = (int)Math.Clamp(elapsed, 0, int.MaxValue);
        var retryAfterSeconds = retryAt is null
            ? null
            : (int?)Math.Clamp(
                Math.Ceiling((retryAt.Value - now).TotalSeconds),
                0,
                int.MaxValue);
        _diagnosticEventSink.Record(DiagnosticExportEvent.ProfileQuotaQueryFinished(
            now,
            TriggerValue(trigger),
            outcome,
            elapsedMilliseconds,
            retryAfterSeconds,
            httpStatus));
    }

    private static string TriggerValue(ProfileQuotaQueryTrigger trigger)
    {
        return trigger == ProfileQuotaQueryTrigger.Manual ? "manual" : "automatic";
    }

    private static string ProxyKindValue(MihomoLocalProxyKind kind)
    {
        return kind switch
        {
            MihomoLocalProxyKind.Mixed => "mixed",
            MihomoLocalProxyKind.Http => "http",
            MihomoLocalProxyKind.Socks => "socks",
            _ => "unknown",
        };
    }
}
