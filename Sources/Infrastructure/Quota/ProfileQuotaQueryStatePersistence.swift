import Foundation
import SQLite3

final class ProfileQuotaQueryStatePersistence {
  private unowned let persistence: QuotaLedgerPersistence

  init(persistence: QuotaLedgerPersistence) {
    self.persistence = persistence
  }

  func upsert(_ state: ProfileQuotaQueryState) throws {
    guard state.consecutiveFailures >= 0, state.automaticRetryCount >= 0 else {
      throw QuotaLedgerError.invalidStoredData
    }
    let statement = try persistence.prepare(
      """
      INSERT INTO quota_query_state(
        subscription_id, last_attempt_at, next_attempt_at, last_queried_url_fingerprint,
        consecutive_failures, retry_day_start, automatic_retry_count
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(subscription_id) DO UPDATE SET
        last_attempt_at = excluded.last_attempt_at,
        next_attempt_at = excluded.next_attempt_at,
        last_queried_url_fingerprint = excluded.last_queried_url_fingerprint,
        consecutive_failures = excluded.consecutive_failures,
        retry_day_start = excluded.retry_day_start,
        automatic_retry_count = excluded.automatic_retry_count
      """
    )
    try statement.bind(state.subscriptionID.uuidString, at: 1)
    try statement.bind(state.lastAttemptAt?.timeIntervalSince1970, at: 2)
    try statement.bind(state.nextAttemptAt?.timeIntervalSince1970, at: 3)
    try statement.bind(state.lastQueriedURLFingerprint, at: 4)
    try statement.bind(Int64(state.consecutiveFailures), at: 5)
    try statement.bind(state.retryDayStart?.timeIntervalSince1970, at: 6)
    try statement.bind(Int64(state.automaticRetryCount), at: 7)
    try statement.step()
  }

  func load(for subscriptionID: UUID) throws -> ProfileQuotaQueryState? {
    let statement = try persistence.prepare(
      """
      SELECT subscription_id, last_attempt_at, next_attempt_at,
             last_queried_url_fingerprint, consecutive_failures,
             retry_day_start, automatic_retry_count
      FROM quota_query_state
      WHERE subscription_id = ?
      """
    )
    try statement.bind(subscriptionID.uuidString, at: 1)
    guard try statement.step() == SQLITE_ROW else {
      return nil
    }
    return try state(from: statement)
  }

  private func state(from statement: SQLiteStatement) throws -> ProfileQuotaQueryState {
    guard
      let subscriptionIDText = statement.text(at: 0),
      let subscriptionID = UUID(uuidString: subscriptionIDText),
      let consecutiveFailures = Int(exactly: statement.int64(at: 4)),
      let automaticRetryCount = Int(exactly: statement.int64(at: 6)),
      consecutiveFailures >= 0,
      automaticRetryCount >= 0
    else {
      throw QuotaLedgerError.invalidStoredData
    }
    return ProfileQuotaQueryState(
      subscriptionID: subscriptionID,
      lastAttemptAt: date(from: statement, at: 1),
      nextAttemptAt: date(from: statement, at: 2),
      lastQueriedURLFingerprint: statement.text(at: 3),
      consecutiveFailures: consecutiveFailures,
      retryDayStart: date(from: statement, at: 5),
      automaticRetryCount: automaticRetryCount
    )
  }

  private func date(from statement: SQLiteStatement, at index: Int32) -> Date? {
    statement.isNull(at: index)
      ? nil : Date(timeIntervalSince1970: statement.double(at: index))
  }
}
