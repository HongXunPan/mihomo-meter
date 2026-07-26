import Foundation
import SQLite3

final class QuotaCyclePersistence {
  private unowned let persistence: QuotaLedgerPersistence

  init(persistence: QuotaLedgerPersistence) {
    self.persistence = persistence
  }

  func insert(_ cycle: QuotaCycle) throws {
    let statement = try persistence.prepare(
      """
      INSERT INTO quota_cycles(
        id, subscription_id, started_at, ended_at, start_reason, is_user_confirmed
      ) VALUES (?, ?, ?, ?, ?, ?)
      """
    )
    try statement.bind(cycle.id.uuidString, at: 1)
    try statement.bind(cycle.subscriptionID.uuidString, at: 2)
    try statement.bind(cycle.startedAt.timeIntervalSince1970, at: 3)
    try statement.bind(cycle.endedAt?.timeIntervalSince1970, at: 4)
    try statement.bind(cycle.startReason.rawValue, at: 5)
    try statement.bind(Int64(cycle.isUserConfirmed ? 1 : 0), at: 6)
    try statement.step()
  }

  func close(id: UUID, at date: Date) throws {
    let statement = try persistence.prepare(
      """
      UPDATE quota_cycles SET ended_at = ?
      WHERE id = ? AND ended_at IS NULL
      """
    )
    try statement.bind(date.timeIntervalSince1970, at: 1)
    try statement.bind(id.uuidString, at: 2)
    try statement.step()
    guard persistence.changeCount == 1 else {
      throw QuotaLedgerError.invalidStoredData
    }
  }

  func load(for subscriptionID: UUID) throws -> [QuotaCycle] {
    let statement = try persistence.prepare(
      """
      SELECT id, subscription_id, started_at, ended_at, start_reason, is_user_confirmed
      FROM quota_cycles
      WHERE subscription_id = ?
      ORDER BY started_at DESC
      """
    )
    try statement.bind(subscriptionID.uuidString, at: 1)
    var cycles: [QuotaCycle] = []
    while try statement.step() == SQLITE_ROW {
      cycles.append(try cycle(from: statement))
    }
    return cycles
  }

  private func cycle(from statement: SQLiteStatement) throws -> QuotaCycle {
    guard
      let idText = statement.text(at: 0),
      let id = UUID(uuidString: idText),
      let subscriptionIDText = statement.text(at: 1),
      let subscriptionID = UUID(uuidString: subscriptionIDText),
      let reasonText = statement.text(at: 4),
      let reason = QuotaCycleStartReason(rawValue: reasonText)
    else {
      throw QuotaLedgerError.invalidStoredData
    }
    return QuotaCycle(
      id: id,
      subscriptionID: subscriptionID,
      startedAt: Date(timeIntervalSince1970: statement.double(at: 2)),
      endedAt: statement.isNull(at: 3)
        ? nil : Date(timeIntervalSince1970: statement.double(at: 3)),
      startReason: reason,
      isUserConfirmed: statement.int64(at: 5) == 1
    )
  }
}
