import Foundation

enum ProfileQuotaQueryTrigger: Equatable, Sendable {
  case automatic
  case manual
}

struct ProfileQuotaSchedulePolicy {
  static let manualRefreshCooldown: TimeInterval = 60
  static let maximumAutomaticRetriesPerDay = 3

  private static let retryDelays: [TimeInterval] = [300, 900, 3_600]

  let calendar: Calendar

  init(calendar: Calendar = .current) {
    self.calendar = calendar
  }

  func dueDate(
    for subscription: TrackedSubscription,
    state: ProfileQuotaQueryState?,
    now: Date
  ) -> Date {
    guard state?.lastQueriedURLFingerprint == subscription.urlFingerprint else {
      return now
    }
    if let nextAttemptAt = state?.nextAttemptAt {
      return nextAttemptAt
    }
    guard let lastAttemptAt = state?.lastAttemptAt else {
      return now
    }
    return lastAttemptAt.addingTimeInterval(refreshInterval(for: subscription))
  }

  func successfulState(
    for subscription: TrackedSubscription,
    at date: Date,
    jitter: TimeInterval
  ) -> ProfileQuotaQueryState {
    ProfileQuotaQueryState(
      subscriptionID: subscription.id,
      lastAttemptAt: date,
      nextAttemptAt: date.addingTimeInterval(refreshInterval(for: subscription) + jitter),
      lastQueriedURLFingerprint: subscription.urlFingerprint,
      consecutiveFailures: 0,
      retryDayStart: nil,
      automaticRetryCount: 0
    )
  }

  func failedState(
    for subscription: TrackedSubscription,
    previous: ProfileQuotaQueryState?,
    trigger: ProfileQuotaQueryTrigger,
    at date: Date,
    jitter: TimeInterval
  ) -> ProfileQuotaQueryState {
    let dayStart = calendar.startOfDay(for: date)
    let isSameRetryDay = previous?.retryDayStart == dayStart
    let previousRetryCount = isSameRetryDay ? previous?.automaticRetryCount ?? 0 : 0
    let wasAutomaticRetry = trigger == .automatic && (previous?.consecutiveFailures ?? 0) > 0
    let retryCount = previousRetryCount + (wasAutomaticRetry ? 1 : 0)
    let failureCount = (previous?.consecutiveFailures ?? 0) + 1
    let hasReachedLimit = retryCount >= Self.maximumAutomaticRetriesPerDay
    let nextAttemptAt =
      hasReachedLimit
      ? date.addingTimeInterval(refreshInterval(for: subscription) + jitter)
      : date.addingTimeInterval(retryDelay(for: failureCount))

    return ProfileQuotaQueryState(
      subscriptionID: subscription.id,
      lastAttemptAt: date,
      nextAttemptAt: nextAttemptAt,
      lastQueriedURLFingerprint: subscription.urlFingerprint,
      consecutiveFailures: hasReachedLimit ? 0 : failureCount,
      retryDayStart: dayStart,
      automaticRetryCount: retryCount
    )
  }

  func manualRefreshAvailableAt(state: ProfileQuotaQueryState?) -> Date? {
    state?.lastAttemptAt?.addingTimeInterval(Self.manualRefreshCooldown)
  }

  private func refreshInterval(for subscription: TrackedSubscription) -> TimeInterval {
    TimeInterval((subscription.refreshIntervalMinutes ?? 360) * 60)
  }

  private func retryDelay(for failureCount: Int) -> TimeInterval {
    let index = min(max(failureCount - 1, 0), Self.retryDelays.count - 1)
    return Self.retryDelays[index]
  }
}
