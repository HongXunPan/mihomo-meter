import Foundation
import SQLite3

final class QuotaSnapshotPersistence {
  private unowned let persistence: QuotaLedgerPersistence

  init(persistence: QuotaLedgerPersistence) {
    self.persistence = persistence
  }

  func insert(_ snapshot: SubscriptionQuotaSnapshot) throws {
    let statement = try persistence.prepare(
      """
      INSERT INTO quota_snapshots(
        id, subscription_id, cycle_id, observed_at, source_updated_at, source,
        upload_bytes, download_bytes, total_bytes, used_bytes, remaining_bytes, expire_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      """
    )
    let traffic = snapshot.traffic
    try statement.bind(snapshot.id.uuidString, at: 1)
    try statement.bind(snapshot.subscriptionID.uuidString, at: 2)
    try statement.bind(snapshot.cycleID.uuidString, at: 3)
    try statement.bind(snapshot.observedAt.timeIntervalSince1970, at: 4)
    try statement.bind(snapshot.observation.sourceUpdatedAt?.timeIntervalSince1970, at: 5)
    try statement.bind(snapshot.source.rawValue, at: 6)
    try statement.bind(try integer(traffic.uploadBytes), at: 7)
    try statement.bind(try integer(traffic.downloadBytes), at: 8)
    try statement.bind(try integer(traffic.totalBytes), at: 9)
    try statement.bind(try integer(traffic.usedBytes), at: 10)
    try statement.bind(try integer(traffic.remainingBytes), at: 11)
    try statement.bind(snapshot.expireAt?.timeIntervalSince1970, at: 12)
    try statement.step()
  }

  func latest(for subscriptionID: UUID) throws -> SubscriptionQuotaSnapshot? {
    let statement = try persistence.prepare(
      """
      \(selection)
      WHERE subscription_id = ?
      ORDER BY observed_at DESC, id DESC
      LIMIT 1
      """
    )
    try statement.bind(subscriptionID.uuidString, at: 1)
    guard try statement.step() == SQLITE_ROW else {
      return nil
    }
    return try snapshot(from: statement)
  }

  func load(
    for subscriptionID: UUID,
    from startDate: Date,
    through endDate: Date
  ) throws -> [SubscriptionQuotaSnapshot] {
    let statement = try persistence.prepare(
      """
      \(selection)
      WHERE subscription_id = ?
        AND COALESCE(source_updated_at, observed_at) >= ?
        AND COALESCE(source_updated_at, observed_at) <= ?
      ORDER BY COALESCE(source_updated_at, observed_at), observed_at, id
      """
    )
    try statement.bind(subscriptionID.uuidString, at: 1)
    try statement.bind(startDate.timeIntervalSince1970, at: 2)
    try statement.bind(endDate.timeIntervalSince1970, at: 3)

    var snapshots: [SubscriptionQuotaSnapshot] = []
    while try statement.step() == SQLITE_ROW {
      snapshots.append(try snapshot(from: statement))
    }
    return snapshots
  }

  private var selection: String {
    """
    SELECT id, subscription_id, cycle_id, observed_at, source_updated_at, source,
           upload_bytes, download_bytes, total_bytes, used_bytes, remaining_bytes, expire_at
    FROM quota_snapshots
    """
  }

  private func snapshot(from statement: SQLiteStatement) throws -> SubscriptionQuotaSnapshot {
    guard
      let idText = statement.text(at: 0),
      let id = UUID(uuidString: idText),
      let subscriptionIDText = statement.text(at: 1),
      let subscriptionID = UUID(uuidString: subscriptionIDText),
      let cycleIDText = statement.text(at: 2),
      let cycleID = UUID(uuidString: cycleIDText),
      let sourceText = statement.text(at: 5),
      let source = QuotaObservationSource(rawValue: sourceText)
    else {
      throw QuotaLedgerError.invalidStoredData
    }
    let traffic = try QuotaTraffic(
      uploadBytes: try unsignedInteger(statement.int64(at: 6)),
      downloadBytes: try unsignedInteger(statement.int64(at: 7)),
      totalBytes: try unsignedInteger(statement.int64(at: 8))
    )
    let storedUsedBytes = try unsignedInteger(statement.int64(at: 9))
    let storedRemainingBytes = try unsignedInteger(statement.int64(at: 10))
    guard
      traffic.usedBytes == storedUsedBytes,
      traffic.remainingBytes == storedRemainingBytes
    else {
      throw QuotaLedgerError.invalidStoredData
    }
    let observation = QuotaObservation(
      subscriptionID: subscriptionID,
      observedAt: Date(timeIntervalSince1970: statement.double(at: 3)),
      sourceUpdatedAt: statement.isNull(at: 4)
        ? nil : Date(timeIntervalSince1970: statement.double(at: 4)),
      source: source,
      traffic: traffic,
      expireAt: statement.isNull(at: 11)
        ? nil : Date(timeIntervalSince1970: statement.double(at: 11))
    )
    return SubscriptionQuotaSnapshot(id: id, cycleID: cycleID, observation: observation)
  }

  private func integer(_ value: UInt64) throws -> Int64 {
    guard let value = Int64(exactly: value) else {
      throw QuotaLedgerError.byteCountOverflow
    }
    return value
  }

  private func unsignedInteger(_ value: Int64) throws -> UInt64 {
    guard value >= 0 else {
      throw QuotaLedgerError.invalidStoredData
    }
    return UInt64(value)
  }
}
