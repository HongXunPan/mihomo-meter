using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public enum ProfileQuotaQueryTrigger
{
    Automatic,
    Manual,
}

public sealed class ProfileQuotaSchedulePolicy
{
    public static readonly TimeSpan ManualRefreshCooldown = TimeSpan.FromSeconds(60);
    public const int MaximumAutomaticRetriesPerDay = 3;
    private static readonly TimeSpan[] RetryDelays =
    {
        TimeSpan.FromMinutes(5),
        TimeSpan.FromMinutes(15),
        TimeSpan.FromHours(1),
    };

    public DateTimeOffset DueDate(
        TrackedSubscription subscription,
        ProfileQuotaQueryState? state,
        DateTimeOffset now)
    {
        if (!string.Equals(
                state?.LastQueriedUrlFingerprint,
                subscription.UrlFingerprint,
                StringComparison.Ordinal))
        {
            return now;
        }

        if (state?.NextAttemptAt is DateTimeOffset nextAttempt)
        {
            return nextAttempt;
        }

        return state?.LastAttemptAt is DateTimeOffset lastAttempt
            ? lastAttempt + RefreshInterval(subscription)
            : now;
    }

    public bool CanRefreshManually(
        ProfileQuotaQueryState? state,
        DateTimeOffset now)
    {
        if (state?.LastAttemptAt is not DateTimeOffset lastAttempt)
        {
            return true;
        }

        if (state.LastFailureCategory is "timeout" or "network")
        {
            return true;
        }

        return now >= lastAttempt + ManualRefreshCooldown;
    }

    public ProfileQuotaQueryState Success(
        TrackedSubscription subscription,
        DateTimeOffset now,
        TimeSpan jitter)
    {
        return new ProfileQuotaQueryState(
            subscription.Id,
            now,
            now + RefreshInterval(subscription) + jitter,
            subscription.UrlFingerprint,
            0,
            null,
            0,
            null);
    }

    public ProfileQuotaQueryState Failure(
        TrackedSubscription subscription,
        ProfileQuotaQueryState? previous,
        ProfileQuotaQueryTrigger trigger,
        DateTimeOffset now,
        TimeSpan jitter,
        string category)
    {
        var dayStart = new DateTimeOffset(now.Year, now.Month, now.Day, 0, 0, 0, now.Offset);
        var sameRetryDay = previous?.RetryDayStart == dayStart;
        var previousRetryCount = sameRetryDay ? previous?.AutomaticRetryCount ?? 0 : 0;
        var wasAutomaticRetry = trigger == ProfileQuotaQueryTrigger.Automatic
            && (previous?.ConsecutiveFailures ?? 0) > 0;
        var retryCount = previousRetryCount + (wasAutomaticRetry ? 1 : 0);
        var failureCount = (previous?.ConsecutiveFailures ?? 0) + 1;
        var reachedLimit = retryCount >= MaximumAutomaticRetriesPerDay;
        var delay = reachedLimit
            ? RefreshInterval(subscription) + jitter
            : RetryDelays[Math.Min(failureCount - 1, RetryDelays.Length - 1)];
        return new ProfileQuotaQueryState(
            subscription.Id,
            now,
            now + delay,
            subscription.UrlFingerprint,
            reachedLimit ? 0 : failureCount,
            dayStart,
            retryCount,
            category);
    }

    private static TimeSpan RefreshInterval(TrackedSubscription subscription)
    {
        return TimeSpan.FromMinutes(subscription.RefreshIntervalMinutes ?? 360);
    }
}
