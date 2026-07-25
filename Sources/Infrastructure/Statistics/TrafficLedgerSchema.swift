import Foundation
import SQLite3

enum TrafficLedgerSchema {
  static let currentVersion = 1

  static func migrate(_ connection: SQLiteConnection) throws {
    let statement = try connection.prepare("PRAGMA user_version")
    guard try statement.step() == SQLITE_ROW else {
      throw TrafficStatisticsError.database("无法读取数据库版本")
    }
    let version = Int(statement.int64(at: 0))
    guard version <= currentVersion else {
      throw TrafficStatisticsError.unsupportedSchema(version)
    }
    guard version == 0 else {
      return
    }

    try connection.transaction {
      try connection.execute(
        """
        CREATE TABLE core_sessions (
          id TEXT PRIMARY KEY,
          mihomo_version TEXT NOT NULL,
          started_at REAL NOT NULL,
          ended_at REAL,
          end_reason TEXT
        )
        """
      )
      try connection.execute(
        """
        CREATE TABLE traffic_buckets (
          bucket_start INTEGER NOT NULL,
          local_day TEXT NOT NULL,
          time_zone_id TEXT NOT NULL,
          core_session_id TEXT NOT NULL,
          category TEXT NOT NULL,
          upload_bytes INTEGER NOT NULL CHECK(upload_bytes >= 0),
          download_bytes INTEGER NOT NULL CHECK(download_bytes >= 0),
          PRIMARY KEY(bucket_start, core_session_id, category),
          FOREIGN KEY(core_session_id) REFERENCES core_sessions(id)
        )
        """
      )
      try connection.execute(
        """
        CREATE INDEX traffic_buckets_retention
        ON traffic_buckets(bucket_start)
        """
      )
      try connection.execute(
        """
        CREATE TABLE traffic_daily_totals (
          local_day TEXT NOT NULL,
          category TEXT NOT NULL,
          upload_bytes INTEGER NOT NULL CHECK(upload_bytes >= 0),
          download_bytes INTEGER NOT NULL CHECK(download_bytes >= 0),
          PRIMARY KEY(local_day, category)
        )
        """
      )
      try connection.execute(
        """
        CREATE TABLE traffic_intervals (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          note TEXT,
          status TEXT NOT NULL,
          started_at REAL NOT NULL,
          ended_at REAL,
          end_reason TEXT,
          start_proxy_upload INTEGER NOT NULL CHECK(start_proxy_upload >= 0),
          start_proxy_download INTEGER NOT NULL CHECK(start_proxy_download >= 0),
          end_proxy_upload INTEGER CHECK(end_proxy_upload >= 0),
          end_proxy_download INTEGER CHECK(end_proxy_download >= 0)
        )
        """
      )
      try connection.execute(
        """
        CREATE TABLE ledger_state (
          id INTEGER PRIMARY KEY CHECK(id = 1),
          current_session_id TEXT,
          current_mihomo_version TEXT,
          last_observed_at REAL,
          last_kernel_upload INTEGER,
          last_kernel_download INTEGER
        )
        """
      )
      try connection.execute("INSERT INTO ledger_state(id) VALUES (1)")
      try connection.execute("PRAGMA user_version = \(currentVersion)")
    }
  }
}
