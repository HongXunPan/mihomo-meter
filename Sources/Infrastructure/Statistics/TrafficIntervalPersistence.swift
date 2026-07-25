import Foundation
import SQLite3

final class TrafficIntervalPersistence {
  private unowned let persistence: TrafficLedgerPersistence

  init(persistence: TrafficLedgerPersistence) {
    self.persistence = persistence
  }

  func load(currentProxyTotal: TrafficBytes) throws -> [TrafficInterval] {
    let statement = try persistence.prepare(
      """
      SELECT id, name, note, status, started_at, ended_at, end_reason,
             start_proxy_upload, start_proxy_download,
             end_proxy_upload, end_proxy_download
      FROM traffic_intervals
      ORDER BY CASE status WHEN 'active' THEN 0 ELSE 1 END, started_at DESC
      """
    )
    var intervals: [TrafficInterval] = []
    while try statement.step() == SQLITE_ROW {
      intervals.append(try interval(from: statement, currentProxyTotal: currentProxyTotal))
    }
    return intervals
  }

  func insert(
    id: UUID,
    name: String,
    note: String?,
    startedAt: Date,
    baseline: TrafficBytes
  ) throws {
    let statement = try persistence.prepare(
      """
      INSERT INTO traffic_intervals(
        id, name, note, status, started_at,
        start_proxy_upload, start_proxy_download
      ) VALUES (?, ?, ?, 'active', ?, ?, ?)
      """
    )
    try statement.bind(id.uuidString, at: 1)
    try statement.bind(name, at: 2)
    try statement.bind(note, at: 3)
    try statement.bind(startedAt.timeIntervalSince1970, at: 4)
    try statement.bind(try integer(baseline.upload), at: 5)
    try statement.bind(try integer(baseline.download), at: 6)
    try statement.step()
  }

  func complete(id: UUID, endedAt: Date, baseline: TrafficBytes) throws {
    let statement = try persistence.prepare(
      """
      UPDATE traffic_intervals
      SET status = 'completed', ended_at = ?, end_reason = 'user',
          end_proxy_upload = ?, end_proxy_download = ?
      WHERE id = ? AND status = 'active'
      """
    )
    try statement.bind(endedAt.timeIntervalSince1970, at: 1)
    try statement.bind(try integer(baseline.upload), at: 2)
    try statement.bind(try integer(baseline.download), at: 3)
    try statement.bind(id.uuidString, at: 4)
    try statement.step()
    guard persistence.changeCount == 1 else {
      throw TrafficStatisticsError.intervalNotActive
    }
  }

  func rename(id: UUID, name: String) throws {
    let statement = try persistence.prepare(
      "UPDATE traffic_intervals SET name = ? WHERE id = ?"
    )
    try statement.bind(name, at: 1)
    try statement.bind(id.uuidString, at: 2)
    try statement.step()
  }

  func delete(id: UUID) throws {
    let statement = try persistence.prepare(
      "DELETE FROM traffic_intervals WHERE id = ?"
    )
    try statement.bind(id.uuidString, at: 1)
    try statement.step()
  }

  func interruptActive(
    endedAt: Date,
    baseline: TrafficBytes,
    reason: TrafficIntervalEndReason
  ) throws {
    let statement = try persistence.prepare(
      """
      UPDATE traffic_intervals
      SET status = 'interrupted',
          ended_at = CASE WHEN started_at > ? THEN started_at ELSE ? END,
          end_reason = ?, end_proxy_upload = ?, end_proxy_download = ?
      WHERE status = 'active'
      """
    )
    try statement.bind(endedAt.timeIntervalSince1970, at: 1)
    try statement.bind(endedAt.timeIntervalSince1970, at: 2)
    try statement.bind(reason.rawValue, at: 3)
    try statement.bind(try integer(baseline.upload), at: 4)
    try statement.bind(try integer(baseline.download), at: 5)
    try statement.step()
  }

  private func interval(
    from statement: SQLiteStatement,
    currentProxyTotal: TrafficBytes
  ) throws -> TrafficInterval {
    guard
      let idText = statement.text(at: 0),
      let id = UUID(uuidString: idText),
      let name = statement.text(at: 1),
      let statusText = statement.text(at: 3),
      let status = TrafficIntervalStatus(rawValue: statusText)
    else {
      throw TrafficStatisticsError.database("统计任务数据无效")
    }

    let startBaseline = try bytes(
      upload: statement.int64(at: 7),
      download: statement.int64(at: 8)
    )
    let endBaseline: TrafficBytes?
    if statement.isNull(at: 9) || statement.isNull(at: 10) {
      endBaseline = nil
    } else {
      endBaseline = try bytes(
        upload: statement.int64(at: 9),
        download: statement.int64(at: 10)
      )
    }
    guard
      let usage = TrafficBytes.nonnegativeDelta(
        current: endBaseline ?? currentProxyTotal,
        previous: startBaseline
      )
    else {
      throw TrafficStatisticsError.database("统计任务累计基线无效")
    }

    return TrafficInterval(
      id: id,
      name: name,
      note: statement.text(at: 2),
      status: status,
      startedAt: Date(timeIntervalSince1970: statement.double(at: 4)),
      endedAt: statement.isNull(at: 5)
        ? nil : Date(timeIntervalSince1970: statement.double(at: 5)),
      endReason: statement.text(at: 6).flatMap(TrafficIntervalEndReason.init(rawValue:)),
      proxyUsage: usage
    )
  }

  private func bytes(upload: Int64, download: Int64) throws -> TrafficBytes {
    guard upload >= 0, download >= 0 else {
      throw TrafficStatisticsError.database("统计任务累计基线无效")
    }
    return TrafficBytes(upload: UInt64(upload), download: UInt64(download))
  }

  private func integer(_ value: UInt64) throws -> Int64 {
    guard value <= UInt64(Int64.max) else {
      throw TrafficStatisticsError.byteCountOverflow
    }
    return Int64(value)
  }
}
