import Foundation
import SQLite3

final class QuotaSubscriptionPersistence {
  private unowned let persistence: QuotaLedgerPersistence

  init(persistence: QuotaLedgerPersistence) {
    self.persistence = persistence
  }

  func upsert(_ subscription: TrackedSubscription) throws {
    let statement = try persistence.prepare(
      """
      INSERT INTO subscriptions(
        id, name, identity_mode, clash_profile_uid, url_fingerprint,
        refresh_interval_minutes, status, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        url_fingerprint = excluded.url_fingerprint,
        refresh_interval_minutes = excluded.refresh_interval_minutes,
        status = excluded.status,
        updated_at = excluded.updated_at
      """
    )
    try statement.bind(subscription.id.uuidString, at: 1)
    try statement.bind(subscription.name, at: 2)
    try statement.bind(subscription.identity.modeRawValue, at: 3)
    try statement.bind(subscription.identity.clashProfileUID, at: 4)
    try statement.bind(subscription.urlFingerprint, at: 5)
    try statement.bind(subscription.refreshIntervalMinutes.map(Int64.init), at: 6)
    try statement.bind(subscription.status.rawValue, at: 7)
    try statement.bind(subscription.createdAt.timeIntervalSince1970, at: 8)
    try statement.bind(subscription.updatedAt.timeIntervalSince1970, at: 9)
    try statement.step()
  }

  func load(id: UUID) throws -> TrackedSubscription? {
    let statement = try persistence.prepare(
      """
      SELECT id, name, identity_mode, clash_profile_uid, url_fingerprint,
             refresh_interval_minutes, status, created_at, updated_at
      FROM subscriptions WHERE id = ?
      """
    )
    try statement.bind(id.uuidString, at: 1)
    guard try statement.step() == SQLITE_ROW else {
      return nil
    }
    return try subscription(from: statement)
  }

  func loadAll() throws -> [TrackedSubscription] {
    let statement = try persistence.prepare(
      """
      SELECT id, name, identity_mode, clash_profile_uid, url_fingerprint,
             refresh_interval_minutes, status, created_at, updated_at
      FROM subscriptions
      ORDER BY CASE status WHEN 'active' THEN 0 WHEN 'paused' THEN 1 ELSE 2 END,
               updated_at DESC
      """
    )
    var subscriptions: [TrackedSubscription] = []
    while try statement.step() == SQLITE_ROW {
      subscriptions.append(try subscription(from: statement))
    }
    return subscriptions
  }

  private func subscription(from statement: SQLiteStatement) throws -> TrackedSubscription {
    guard
      let idText = statement.text(at: 0),
      let id = UUID(uuidString: idText),
      let name = statement.text(at: 1),
      let identityMode = statement.text(at: 2),
      let statusText = statement.text(at: 6),
      let status = SubscriptionTrackingStatus(rawValue: statusText)
    else {
      throw QuotaLedgerError.invalidStoredData
    }
    let identity = try identity(
      mode: identityMode,
      clashProfileUID: statement.text(at: 3)
    )
    let refreshInterval = statement.isNull(at: 5) ? nil : Int(statement.int64(at: 5))
    return try TrackedSubscription(
      id: id,
      name: name,
      identity: identity,
      urlFingerprint: statement.text(at: 4),
      refreshIntervalMinutes: refreshInterval,
      status: status,
      createdAt: Date(timeIntervalSince1970: statement.double(at: 7)),
      updatedAt: Date(timeIntervalSince1970: statement.double(at: 8))
    )
  }

  private func identity(
    mode: String,
    clashProfileUID: String?
  ) throws -> SubscriptionIdentity {
    switch mode {
    case "runtime_single" where clashProfileUID == nil:
      return .runtimeSingle
    case "clash_profile":
      guard let clashProfileUID else {
        throw QuotaLedgerError.invalidStoredData
      }
      return .clashProfile(uid: clashProfileUID)
    default:
      throw QuotaLedgerError.invalidStoredData
    }
  }
}
