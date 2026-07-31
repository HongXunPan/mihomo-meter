import Foundation
import SQLite3

struct TrafficLedgerRuntimeState: Equatable {
  var currentSessionID: UUID?
  var currentMihomoVersion: String?
  var lastObservedAt: Date?
  var lastKernelTotal: TrafficBytes?
}

final class TrafficLedgerPersistence {
  let databaseURL: URL
  private var connection: SQLiteConnection
  var intervals: TrafficIntervalPersistence {
    TrafficIntervalPersistence(persistence: self)
  }
  var changeCount: Int32 {
    sqlite3_changes(connection.handle)
  }

  init(databaseURL: URL) throws {
    self.databaseURL = databaseURL
    connection = try SQLiteConnection(fileURL: databaseURL)
    try TrafficLedgerSchema.migrate(connection)
  }

  func close() {
    connection.close()
  }

  func reset() throws {
    close()
    for url in databaseFiles {
      guard FileManager.default.fileExists(atPath: url.path) else {
        continue
      }
      try FileManager.default.removeItem(at: url)
    }
    connection = try SQLiteConnection(fileURL: databaseURL)
    try TrafficLedgerSchema.migrate(connection)
  }

  func loadRuntimeState() throws -> TrafficLedgerRuntimeState {
    let statement = try connection.prepare(
      """
      SELECT current_session_id, current_mihomo_version, last_observed_at,
             last_kernel_upload, last_kernel_download
      FROM ledger_state WHERE id = 1
      """
    )
    guard try statement.step() == SQLITE_ROW else {
      throw TrafficStatisticsError.database("缺少统计运行状态")
    }

    let sessionID = statement.text(at: 0).flatMap(UUID.init(uuidString:))
    let lastObservedAt =
      statement.isNull(at: 2) ? nil : Date(timeIntervalSince1970: statement.double(at: 2))
    let lastKernelTotal: TrafficBytes?
    if statement.isNull(at: 3) || statement.isNull(at: 4) {
      lastKernelTotal = nil
    } else {
      lastKernelTotal = TrafficBytes(
        upload: UInt64(statement.int64(at: 3)),
        download: UInt64(statement.int64(at: 4))
      )
    }
    return TrafficLedgerRuntimeState(
      currentSessionID: sessionID,
      currentMihomoVersion: statement.text(at: 1),
      lastObservedAt: lastObservedAt,
      lastKernelTotal: lastKernelTotal
    )
  }

  func saveRuntimeState(_ state: TrafficLedgerRuntimeState) throws {
    let statement = try connection.prepare(
      """
      UPDATE ledger_state
      SET current_session_id = ?, current_mihomo_version = ?, last_observed_at = ?,
          last_kernel_upload = ?, last_kernel_download = ?
      WHERE id = 1
      """
    )
    try statement.bind(state.currentSessionID?.uuidString, at: 1)
    try statement.bind(state.currentMihomoVersion, at: 2)
    try statement.bind(state.lastObservedAt?.timeIntervalSince1970, at: 3)
    try statement.bind(try state.lastKernelTotal.map { try integer($0.upload) }, at: 4)
    try statement.bind(try state.lastKernelTotal.map { try integer($0.download) }, at: 5)
    try statement.step()
  }

  func createCoreSession(id: UUID, version: String, startedAt: Date) throws {
    let statement = try connection.prepare(
      """
      INSERT INTO core_sessions(id, mihomo_version, started_at)
      VALUES (?, ?, ?)
      """
    )
    try statement.bind(id.uuidString, at: 1)
    try statement.bind(version, at: 2)
    try statement.bind(startedAt.timeIntervalSince1970, at: 3)
    try statement.step()
  }

  func closeCoreSession(id: UUID, endedAt: Date, reason: String) throws {
    let statement = try connection.prepare(
      """
      UPDATE core_sessions
      SET ended_at = ?, end_reason = ?
      WHERE id = ? AND ended_at IS NULL
      """
    )
    try statement.bind(endedAt.timeIntervalSince1970, at: 1)
    try statement.bind(reason, at: 2)
    try statement.bind(id.uuidString, at: 3)
    try statement.step()
  }

  func add(
    _ categories: CategorizedTrafficBytes,
    observedAt: Date,
    calendar: Calendar,
    coreSessionID: UUID
  ) throws {
    let bucketStart = Int64(floor(observedAt.timeIntervalSince1970 / 60) * 60)
    let localDay = Self.localDay(for: observedAt, calendar: calendar)
    let timeZoneID = calendar.timeZone.identifier

    for category in TrafficCategory.allCases {
      let bytes = categories.bytes(for: category)
      guard bytes != .zero else {
        continue
      }
      try upsertBucket(
        start: bucketStart,
        localDay: localDay,
        timeZoneID: timeZoneID,
        sessionID: coreSessionID,
        category: category,
        bytes: bytes
      )
      try upsertDailyTotal(localDay: localDay, category: category, bytes: bytes)
    }
  }

  func pruneBuckets(before date: Date) throws {
    let statement = try connection.prepare(
      "DELETE FROM traffic_buckets WHERE bucket_start < ?"
    )
    try statement.bind(Int64(date.timeIntervalSince1970), at: 1)
    try statement.step()
  }

  func totals(localDay: String? = nil) throws -> CategorizedTrafficBytes {
    let sql =
      localDay == nil
      ? """
      SELECT category, SUM(upload_bytes), SUM(download_bytes)
      FROM traffic_daily_totals GROUP BY category
      """
      : """
      SELECT category, upload_bytes, download_bytes
      FROM traffic_daily_totals WHERE local_day = ?
      """
    let statement = try connection.prepare(sql)
    if let localDay {
      try statement.bind(localDay, at: 1)
    }

    var totals = CategorizedTrafficBytes.zero
    while try statement.step() == SQLITE_ROW {
      guard
        let rawCategory = statement.text(at: 0),
        let category = TrafficCategory(rawValue: rawCategory)
      else {
        throw TrafficStatisticsError.database("统计分类无效")
      }
      let bytes = TrafficBytes(
        upload: UInt64(statement.int64(at: 1)),
        download: UInt64(statement.int64(at: 2))
      )
      totals = totals.adding(bytes, to: category)
    }
    return totals
  }

  func dailyTotals(
    category: TrafficCategory,
    since cutoffLocalDay: String
  ) throws -> [TrafficDailyTotal] {
    let statement = try connection.prepare(
      """
      SELECT local_day, upload_bytes, download_bytes
      FROM traffic_daily_totals
      WHERE category = ? AND local_day >= ?
      ORDER BY local_day ASC
      """
    )
    try statement.bind(category.rawValue, at: 1)
    try statement.bind(cutoffLocalDay, at: 2)
    var totals: [TrafficDailyTotal] = []
    while try statement.step() == SQLITE_ROW {
      guard let localDay = statement.text(at: 0) else {
        throw TrafficStatisticsError.database("每日统计日期无效")
      }
      totals.append(
        TrafficDailyTotal(
          localDay: localDay,
          bytes: TrafficBytes(
            upload: UInt64(statement.int64(at: 1)),
            download: UInt64(statement.int64(at: 2))
          )
        )
      )
    }
    return totals
  }

  func transaction<Result>(_ body: () throws -> Result) throws -> Result {
    try connection.transaction(body)
  }

  func prepare(_ sql: String) throws -> SQLiteStatement {
    try connection.prepare(sql)
  }

  func protectFiles() throws {
    try connection.protectDatabaseFiles()
  }

  static func localDay(for date: Date, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(
      format: "%04d-%02d-%02d",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0
    )
  }

  private var databaseFiles: [URL] {
    [
      databaseURL,
      URL(fileURLWithPath: databaseURL.path + "-wal"),
      URL(fileURLWithPath: databaseURL.path + "-shm"),
    ]
  }

  private func upsertBucket(
    start: Int64,
    localDay: String,
    timeZoneID: String,
    sessionID: UUID,
    category: TrafficCategory,
    bytes: TrafficBytes
  ) throws {
    let statement = try connection.prepare(
      """
      INSERT INTO traffic_buckets(
        bucket_start, local_day, time_zone_id, core_session_id,
        category, upload_bytes, download_bytes
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(bucket_start, core_session_id, category) DO UPDATE SET
        upload_bytes = upload_bytes + excluded.upload_bytes,
        download_bytes = download_bytes + excluded.download_bytes
      """
    )
    try statement.bind(start, at: 1)
    try statement.bind(localDay, at: 2)
    try statement.bind(timeZoneID, at: 3)
    try statement.bind(sessionID.uuidString, at: 4)
    try statement.bind(category.rawValue, at: 5)
    try statement.bind(try integer(bytes.upload), at: 6)
    try statement.bind(try integer(bytes.download), at: 7)
    try statement.step()
  }

  private func upsertDailyTotal(
    localDay: String,
    category: TrafficCategory,
    bytes: TrafficBytes
  ) throws {
    let statement = try connection.prepare(
      """
      INSERT INTO traffic_daily_totals(
        local_day, category, upload_bytes, download_bytes
      ) VALUES (?, ?, ?, ?)
      ON CONFLICT(local_day, category) DO UPDATE SET
        upload_bytes = upload_bytes + excluded.upload_bytes,
        download_bytes = download_bytes + excluded.download_bytes
      """
    )
    try statement.bind(localDay, at: 1)
    try statement.bind(category.rawValue, at: 2)
    try statement.bind(try integer(bytes.upload), at: 3)
    try statement.bind(try integer(bytes.download), at: 4)
    try statement.step()
  }

  private func integer(_ value: UInt64) throws -> Int64 {
    guard value <= UInt64(Int64.max) else {
      throw TrafficStatisticsError.byteCountOverflow
    }
    return Int64(value)
  }
}

extension CategorizedTrafficBytes {
  func bytes(for category: TrafficCategory) -> TrafficBytes {
    switch category {
    case .proxy:
      proxy
    case .direct:
      direct
    case .reject:
      reject
    case .unknown:
      unknown
    }
  }
}
