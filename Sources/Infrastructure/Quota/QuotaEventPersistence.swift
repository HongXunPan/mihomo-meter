import Foundation
import SQLite3

final class QuotaEventPersistence {
  private unowned let persistence: QuotaLedgerPersistence

  init(persistence: QuotaLedgerPersistence) {
    self.persistence = persistence
  }

  func insert(_ event: QuotaEvent) throws {
    let statement = try persistence.prepare(
      """
      INSERT INTO quota_events(
        id, subscription_id, previous_snapshot_id, current_snapshot_id,
        occurred_at, kind, is_user_confirmed
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      """
    )
    try statement.bind(event.id.uuidString, at: 1)
    try statement.bind(event.subscriptionID.uuidString, at: 2)
    try statement.bind(event.previousSnapshotID.uuidString, at: 3)
    try statement.bind(event.currentSnapshotID.uuidString, at: 4)
    try statement.bind(event.occurredAt.timeIntervalSince1970, at: 5)
    try statement.bind(event.kind.rawValue, at: 6)
    try statement.bind(Int64(event.isUserConfirmed ? 1 : 0), at: 7)
    try statement.step()
  }

  func load(for subscriptionID: UUID, limit: Int) throws -> [QuotaEvent] {
    let statement = try persistence.prepare(
      """
      SELECT id, subscription_id, previous_snapshot_id, current_snapshot_id,
             occurred_at, kind, is_user_confirmed
      FROM quota_events
      WHERE subscription_id = ?
      ORDER BY occurred_at DESC, id DESC
      LIMIT ?
      """
    )
    try statement.bind(subscriptionID.uuidString, at: 1)
    try statement.bind(Int64(limit), at: 2)
    var events: [QuotaEvent] = []
    while try statement.step() == SQLITE_ROW {
      events.append(try event(from: statement))
    }
    return events
  }

  func confirmUsageReset(cycleID: UUID) throws {
    let statement = try persistence.prepare(
      """
      UPDATE quota_events SET is_user_confirmed = 1
      WHERE kind = 'usage_reset'
        AND is_user_confirmed = 0
        AND current_snapshot_id IN (
          SELECT id FROM quota_snapshots WHERE cycle_id = ?
        )
      """
    )
    try statement.bind(cycleID.uuidString, at: 1)
    try statement.step()
    guard persistence.changeCount == 1 else {
      throw QuotaLedgerError.invalidStoredData
    }
  }

  private func event(from statement: SQLiteStatement) throws -> QuotaEvent {
    guard
      let idText = statement.text(at: 0),
      let id = UUID(uuidString: idText),
      let subscriptionIDText = statement.text(at: 1),
      let subscriptionID = UUID(uuidString: subscriptionIDText),
      let previousSnapshotIDText = statement.text(at: 2),
      let previousSnapshotID = UUID(uuidString: previousSnapshotIDText),
      let currentSnapshotIDText = statement.text(at: 3),
      let currentSnapshotID = UUID(uuidString: currentSnapshotIDText),
      let kindText = statement.text(at: 5),
      let kind = QuotaEventKind(rawValue: kindText)
    else {
      throw QuotaLedgerError.invalidStoredData
    }
    return QuotaEvent(
      id: id,
      subscriptionID: subscriptionID,
      previousSnapshotID: previousSnapshotID,
      currentSnapshotID: currentSnapshotID,
      occurredAt: Date(timeIntervalSince1970: statement.double(at: 4)),
      kind: kind,
      isUserConfirmed: statement.int64(at: 6) == 1
    )
  }
}
