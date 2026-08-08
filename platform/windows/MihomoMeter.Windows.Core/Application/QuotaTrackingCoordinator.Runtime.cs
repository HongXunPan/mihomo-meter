using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Core.Application;

public sealed partial class QuotaTrackingCoordinator
{
    public Task EnableRuntimeTrackingAsync(CancellationToken cancellationToken = default)
    {
        return ExecuteOperationAsync(async () =>
        {
            var candidate = _latestRuntimeCandidate
                ?? throw new QuotaDomainException("当前没有唯一有效的订阅配额候选。");
            var now = _timeProvider.GetUtcNow();
            var existing = RuntimeSubscription();
            var subscription = existing is null
                ? new TrackedSubscription(
                    Guid.NewGuid(),
                    "当前运行订阅",
                    SubscriptionIdentityMode.RuntimeSingle,
                    null,
                    null,
                    null,
                    SubscriptionTrackingStatus.Active,
                    now,
                    now)
                : new TrackedSubscription(
                    existing.Id,
                    existing.Name,
                    existing.IdentityMode,
                    null,
                    null,
                    null,
                    SubscriptionTrackingStatus.Active,
                    existing.CreatedAt,
                    now);
            _ledgerSnapshot = await _ledger
                .UpsertSubscriptionAsync(subscription, now, cancellationToken)
                .ConfigureAwait(false);
            _runtimeSourceKey = candidate.SourceKey;
            await RecordRuntimeCandidateCoreAsync(candidate, cancellationToken)
                .ConfigureAwait(false);
            _message = null;
            Publish(QuotaAvailability.Available);
        }, cancellationToken);
    }

    public Task PauseRuntimeTrackingAsync(CancellationToken cancellationToken = default)
    {
        return ExecuteOperationAsync(
            () => PauseRuntimeSubscriptionCoreAsync(
                "当前运行订阅追踪已暂停。",
                cancellationToken),
            cancellationToken);
    }

    private async Task RunRuntimeObservationAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            await ObserveRuntimeOnceAsync(cancellationToken).ConfigureAwait(false);
            await Task.Delay(
                RuntimeObservationInterval,
                _timeProvider,
                cancellationToken).ConfigureAwait(false);
        }
    }

    private Task ObserveRuntimeOnceAsync(CancellationToken cancellationToken)
    {
        return ExecuteOperationAsync(async () =>
        {
            var endpoint = _endpoint
                ?? throw new QuotaDomainException("Mihomo Controller 当前不可用。");
            MihomoProxyProvidersResponse response;
            try
            {
                response = await _controllerClient
                    .FetchProxyProvidersAsync(endpoint, _secret, cancellationToken)
                    .ConfigureAwait(false);
            }
            catch (MihomoControllerException)
            {
                _latestRuntimeCandidate = null;
                _runtimeCandidateCount = 0;
                _runtimeStatus = RuntimeQuotaObservationStatus.Failed;
                _message = "读取当前运行订阅配额失败，已保留历史。";
                Publish(QuotaAvailability.Available);
                return;
            }

            var selection = response.ToRuntimeSelection();
            _runtimeCandidateCount = selection.CandidateCount;
            _latestRuntimeCandidate = selection.Candidate;
            _runtimeStatus = selection.Kind switch
            {
                RuntimeQuotaCandidateSelectionKind.None =>
                    RuntimeQuotaObservationStatus.NoCandidate,
                RuntimeQuotaCandidateSelectionKind.Single =>
                    RuntimeQuotaObservationStatus.SingleCandidate,
                RuntimeQuotaCandidateSelectionKind.Multiple =>
                    RuntimeQuotaObservationStatus.MultipleCandidates,
                _ => RuntimeQuotaObservationStatus.Failed,
            };

            if (selection.Kind != RuntimeQuotaCandidateSelectionKind.Single)
            {
                await PauseRuntimeSubscriptionCoreAsync(
                    selection.Kind == RuntimeQuotaCandidateSelectionKind.None
                        ? "当前运行配置没有唯一配额候选，轻量追踪已暂停。"
                        : "当前运行配置存在多个配额候选，轻量追踪已暂停。",
                    cancellationToken).ConfigureAwait(false);
                return;
            }

            var subscription = RuntimeSubscription();
            if (subscription?.Status != SubscriptionTrackingStatus.Active
                || selection.Candidate is null)
            {
                Publish(QuotaAvailability.Available);
                return;
            }

            if (_runtimeSourceKey is not null
                && !string.Equals(
                    _runtimeSourceKey,
                    selection.Candidate.SourceKey,
                    StringComparison.Ordinal))
            {
                await PauseRuntimeSubscriptionCoreAsync(
                    "运行订阅来源发生变化，轻量追踪已暂停。",
                    cancellationToken).ConfigureAwait(false);
                return;
            }

            _runtimeSourceKey = selection.Candidate.SourceKey;
            await RecordRuntimeCandidateCoreAsync(
                selection.Candidate,
                cancellationToken).ConfigureAwait(false);
        }, cancellationToken);
    }

    private async Task RecordRuntimeCandidateCoreAsync(
        RuntimeQuotaCandidate candidate,
        CancellationToken cancellationToken)
    {
        var subscription = RuntimeSubscription();
        if (subscription is null)
        {
            return;
        }

        var latest = _ledgerSnapshot.Subscriptions
            .FirstOrDefault(item => item.Subscription.Id == subscription.Id)?
            .LatestSnapshot;
        var duplicatesLatest = latest is not null
            && latest.Traffic == candidate.Traffic
            && latest.ExpireAt == candidate.ExpireAt
            && (candidate.SourceUpdatedAt is null
                || latest.SourceUpdatedAt == candidate.SourceUpdatedAt);
        if (duplicatesLatest)
        {
            return;
        }

        var now = _timeProvider.GetUtcNow();
        _ledgerSnapshot = await _ledger
            .RecordAsync(
                new QuotaObservation(
                    subscription.Id,
                    now,
                    candidate.SourceUpdatedAt,
                    QuotaObservationSource.MihomoRuntime,
                    candidate.Traffic,
                    candidate.ExpireAt),
                now,
                cancellationToken)
            .ConfigureAwait(false);
        _message = null;
        Publish(QuotaAvailability.Available);
    }

    private async Task PauseRuntimeSubscriptionCoreAsync(
        string message,
        CancellationToken cancellationToken)
    {
        var subscription = RuntimeSubscription();
        if (subscription?.Status == SubscriptionTrackingStatus.Active)
        {
            var now = _timeProvider.GetUtcNow();
            _ledgerSnapshot = await _ledger
                .SetSubscriptionStatusAsync(
                    subscription.Id,
                    SubscriptionTrackingStatus.Paused,
                    now,
                    cancellationToken)
                .ConfigureAwait(false);
        }

        _runtimeSourceKey = null;
        _message = message;
        Publish(QuotaAvailability.Available);
    }

    private TrackedSubscription? RuntimeSubscription()
    {
        return _ledgerSnapshot.Subscriptions
            .Select(item => item.Subscription)
            .FirstOrDefault(subscription =>
                subscription.IdentityMode == SubscriptionIdentityMode.RuntimeSingle);
    }
}
