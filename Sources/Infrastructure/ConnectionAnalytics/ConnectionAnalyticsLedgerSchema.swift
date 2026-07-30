import SQLite3

enum ConnectionAnalyticsLedgerSchema {
  static let currentVersion = 1

  static func migrate(_ connection: SQLiteConnection) throws {
    let statement = try connection.prepare("PRAGMA user_version")
    guard try statement.step() == SQLITE_ROW else {
      throw ConnectionAnalyticsError.database("无法读取数据库版本")
    }
    let version = Int(statement.int64(at: 0))
    guard version <= currentVersion else {
      throw ConnectionAnalyticsError.unsupportedSchema(version)
    }
    guard version == 0 else {
      return
    }

    try connection.transaction {
      try connection.execute(
        """
        CREATE TABLE connection_analytics_settings (
          id INTEGER PRIMARY KEY CHECK(id = 1),
          history_enabled INTEGER NOT NULL CHECK(history_enabled IN (0, 1))
        )
        """
      )
      try connection.execute(
        "INSERT INTO connection_analytics_settings(id, history_enabled) VALUES (1, 0)"
      )
      try connection.execute(
        """
        CREATE TABLE connection_daily_attribution (
          local_day TEXT NOT NULL,
          application_name TEXT NOT NULL,
          hostname TEXT NOT NULL,
          upload_bytes INTEGER NOT NULL CHECK(upload_bytes >= 0),
          download_bytes INTEGER NOT NULL CHECK(download_bytes >= 0),
          PRIMARY KEY(local_day, application_name, hostname)
        )
        """
      )
      try connection.execute(
        """
        CREATE INDEX connection_daily_attribution_retention
        ON connection_daily_attribution(local_day)
        """
      )
      try connection.execute("PRAGMA user_version = \(currentVersion)")
    }
  }
}
