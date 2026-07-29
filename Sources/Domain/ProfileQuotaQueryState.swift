import Foundation

struct ProfileQuotaQueryState: Equatable, Sendable {
  let subscriptionID: UUID
  let lastAttemptAt: Date?
  let nextAttemptAt: Date?
  let lastQueriedURLFingerprint: String?
  let consecutiveFailures: Int
  let retryDayStart: Date?
  let automaticRetryCount: Int
}
