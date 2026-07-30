import Foundation
import SQLite3

final class ConnectionAnalyticsLedgerPersistence {
  let databaseURL: URL
  private let connection: SQLiteConnection

  init(databaseURL: URL) throws {
    self.databaseURL = databaseURL
    connection = try SQLiteConnection(fileURL: databaseURL)
    try ConnectionAnalyticsLedgerSchema.migrate(connection)
  }

  func transaction<Result>(_ body: () throws -> Result) throws -> Result {
    try connection.transaction(body)
  }

  func isHistoryEnabled() throws -> Bool {
    let statement = try connection.prepare(
      "SELECT history_enabled FROM connection_analytics_settings WHERE id = 1"
    )
    guard try statement.step() == SQLITE_ROW else {
      throw ConnectionAnalyticsError.database("缺少连接归因设置")
    }
    return statement.int64(at: 0) == 1
  }

  func setHistoryEnabled(_ isEnabled: Bool) throws {
    let statement = try connection.prepare(
      "UPDATE connection_analytics_settings SET history_enabled = ? WHERE id = 1"
    )
    try statement.bind(Int64(isEnabled ? 1 : 0), at: 1)
    try statement.step()
  }

  func existingKeys(localDay: String) throws -> Set<ConnectionAttributionStorageKey> {
    let statement = try connection.prepare(
      """
      SELECT application_name, hostname
      FROM connection_daily_attribution
      WHERE local_day = ?
      """
    )
    try statement.bind(localDay, at: 1)
    var keys: Set<ConnectionAttributionStorageKey> = []
    while try statement.step() == SQLITE_ROW {
      guard let applicationName = statement.text(at: 0), let hostname = statement.text(at: 1)
      else {
        throw ConnectionAnalyticsError.database("连接归因键无效")
      }
      keys.insert(
        ConnectionAttributionStorageKey(
          localDay: localDay,
          applicationName: applicationName,
          hostname: hostname
        )
      )
    }
    return keys
  }

  func upsert(_ aggregate: ConnectionAttributionAggregate) throws {
    let statement = try connection.prepare(
      """
      INSERT INTO connection_daily_attribution(
        local_day, application_name, hostname, upload_bytes, download_bytes
      ) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(local_day, application_name, hostname) DO UPDATE SET
        upload_bytes = upload_bytes + excluded.upload_bytes,
        download_bytes = download_bytes + excluded.download_bytes
      """
    )
    try statement.bind(aggregate.key.localDay, at: 1)
    try statement.bind(aggregate.key.applicationName, at: 2)
    try statement.bind(aggregate.key.hostname, at: 3)
    try statement.bind(try integer(aggregate.bytes.upload), at: 4)
    try statement.bind(try integer(aggregate.bytes.download), at: 5)
    try statement.step()
  }

  func dailyTotals(since cutoffLocalDay: String) throws -> [ConnectionAnalyticsDay] {
    let statement = try connection.prepare(
      """
      SELECT local_day,
             SUM(upload_bytes), SUM(download_bytes),
             SUM(CASE WHEN hostname != ? THEN upload_bytes ELSE 0 END),
             SUM(CASE WHEN hostname != ? THEN download_bytes ELSE 0 END),
             SUM(CASE WHEN application_name != ? THEN upload_bytes ELSE 0 END),
             SUM(CASE WHEN application_name != ? THEN download_bytes ELSE 0 END),
             SUM(CASE WHEN hostname != ? AND application_name != ?
                      THEN upload_bytes ELSE 0 END),
             SUM(CASE WHEN hostname != ? AND application_name != ?
                      THEN download_bytes ELSE 0 END)
      FROM connection_daily_attribution
      WHERE local_day >= ?
      GROUP BY local_day
      ORDER BY local_day ASC
      """
    )
    try statement.bind(ConnectionAttributionLabel.unknownHostname, at: 1)
    try statement.bind(ConnectionAttributionLabel.unknownHostname, at: 2)
    try statement.bind(ConnectionAttributionLabel.unknownApplication, at: 3)
    try statement.bind(ConnectionAttributionLabel.unknownApplication, at: 4)
    try statement.bind(ConnectionAttributionLabel.unknownHostname, at: 5)
    try statement.bind(ConnectionAttributionLabel.unknownApplication, at: 6)
    try statement.bind(ConnectionAttributionLabel.unknownHostname, at: 7)
    try statement.bind(ConnectionAttributionLabel.unknownApplication, at: 8)
    try statement.bind(cutoffLocalDay, at: 9)

    var days: [ConnectionAnalyticsDay] = []
    while try statement.step() == SQLITE_ROW {
      guard let localDay = statement.text(at: 0) else {
        throw ConnectionAnalyticsError.database("连接归因日期无效")
      }
      let total = bytes(from: statement, uploadIndex: 1, downloadIndex: 2)
      days.append(
        ConnectionAnalyticsDay(
          localDay: localDay,
          bytes: total,
          coverage: ConnectionAnalyticsCoverage(
            total: total,
            hostnameAttributed: bytes(from: statement, uploadIndex: 3, downloadIndex: 4),
            applicationAttributed: bytes(
              from: statement,
              uploadIndex: 5,
              downloadIndex: 6
            ),
            fullyAttributed: bytes(from: statement, uploadIndex: 7, downloadIndex: 8)
          )
        )
      )
    }
    return days
  }

  func records(localDay: String) throws -> [ConnectionAttributionRecord] {
    let statement = try connection.prepare(
      """
      SELECT application_name, hostname, upload_bytes, download_bytes
      FROM connection_daily_attribution
      WHERE local_day = ?
      ORDER BY upload_bytes + download_bytes DESC, application_name, hostname
      """
    )
    try statement.bind(localDay, at: 1)
    var records: [ConnectionAttributionRecord] = []
    while try statement.step() == SQLITE_ROW {
      guard let applicationName = statement.text(at: 0), let hostname = statement.text(at: 1)
      else {
        throw ConnectionAnalyticsError.database("连接归因记录无效")
      }
      records.append(
        ConnectionAttributionRecord(
          localDay: localDay,
          applicationName: applicationName,
          hostname: hostname,
          bytes: bytes(from: statement, uploadIndex: 2, downloadIndex: 3)
        )
      )
    }
    return records
  }

  func prune(before cutoffLocalDay: String) throws {
    let statement = try connection.prepare(
      "DELETE FROM connection_daily_attribution WHERE local_day < ?"
    )
    try statement.bind(cutoffLocalDay, at: 1)
    try statement.step()
  }

  func clearHistory() throws {
    try connection.execute("DELETE FROM connection_daily_attribution")
  }

  private func bytes(
    from statement: SQLiteStatement,
    uploadIndex: Int32,
    downloadIndex: Int32
  ) -> TrafficBytes {
    TrafficBytes(
      upload: UInt64(statement.int64(at: uploadIndex)),
      download: UInt64(statement.int64(at: downloadIndex))
    )
  }

  private func integer(_ value: UInt64) throws -> Int64 {
    guard value <= UInt64(Int64.max) else {
      throw ConnectionAnalyticsError.byteCountOverflow
    }
    return Int64(value)
  }
}
