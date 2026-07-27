import Foundation
import SQLite3

enum QuotaLedgerSchema {
  static let currentVersion = 3

  static func migrate(_ connection: SQLiteConnection) throws {
    let statement = try connection.prepare("PRAGMA user_version")
    guard try statement.step() == SQLITE_ROW else {
      throw QuotaLedgerError.invalidStoredData
    }
    let version = Int(statement.int64(at: 0))
    guard version <= currentVersion else {
      throw QuotaLedgerError.unsupportedSchema(version)
    }
    switch version {
    case 0:
      try connection.transaction {
        try createSubscriptions(connection)
        try createCycles(connection)
        try createSnapshots(connection)
        try createQueryStates(connection)
        try createEvents(connection)
        try connection.execute("PRAGMA user_version = \(currentVersion)")
      }
    case 1:
      try connection.transaction {
        try createQueryStates(connection)
        try createEvents(connection)
        try connection.execute("PRAGMA user_version = \(currentVersion)")
      }
    case 2:
      try connection.transaction {
        try createEvents(connection)
        try connection.execute("PRAGMA user_version = \(currentVersion)")
      }
    case currentVersion:
      return
    default:
      throw QuotaLedgerError.unsupportedSchema(version)
    }
  }

  private static func createSubscriptions(_ connection: SQLiteConnection) throws {
    try connection.execute(
      """
      CREATE TABLE subscriptions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL CHECK(length(trim(name)) > 0),
        identity_mode TEXT NOT NULL CHECK(identity_mode IN ('runtime_single', 'clash_profile')),
        clash_profile_uid TEXT,
        url_fingerprint TEXT,
        refresh_interval_minutes INTEGER CHECK(
          refresh_interval_minutes IS NULL OR refresh_interval_minutes >= 60
        ),
        status TEXT NOT NULL CHECK(status IN ('active', 'paused', 'archived', 'unsupported')),
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL,
        CHECK(created_at <= updated_at),
        CHECK(
          (identity_mode = 'runtime_single'
            AND clash_profile_uid IS NULL
            AND refresh_interval_minutes IS NULL)
          OR
          (identity_mode = 'clash_profile'
            AND length(trim(clash_profile_uid)) > 0
            AND refresh_interval_minutes >= 60)
        )
      )
      """
    )
  }

  private static func createCycles(_ connection: SQLiteConnection) throws {
    try connection.execute(
      """
      CREATE TABLE quota_cycles (
        id TEXT PRIMARY KEY,
        subscription_id TEXT NOT NULL,
        started_at REAL NOT NULL,
        ended_at REAL,
        start_reason TEXT NOT NULL CHECK(start_reason IN ('initial', 'usage_reset')),
        is_user_confirmed INTEGER NOT NULL CHECK(is_user_confirmed IN (0, 1)),
        CHECK(ended_at IS NULL OR ended_at >= started_at),
        FOREIGN KEY(subscription_id) REFERENCES subscriptions(id)
      )
      """
    )
    try connection.execute(
      """
      CREATE UNIQUE INDEX quota_cycles_one_open
      ON quota_cycles(subscription_id)
      WHERE ended_at IS NULL
      """
    )
    try connection.execute(
      """
      CREATE INDEX quota_cycles_history
      ON quota_cycles(subscription_id, started_at DESC)
      """
    )
  }

  private static func createSnapshots(_ connection: SQLiteConnection) throws {
    try connection.execute(
      """
      CREATE TABLE quota_snapshots (
        id TEXT PRIMARY KEY,
        subscription_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL,
        observed_at REAL NOT NULL,
        source_updated_at REAL,
        source TEXT NOT NULL CHECK(source IN ('mihomo_runtime', 'meter_active_query')),
        upload_bytes INTEGER NOT NULL CHECK(upload_bytes >= 0),
        download_bytes INTEGER NOT NULL CHECK(download_bytes >= 0),
        total_bytes INTEGER NOT NULL CHECK(total_bytes > 0),
        used_bytes INTEGER NOT NULL CHECK(used_bytes >= 0),
        remaining_bytes INTEGER NOT NULL CHECK(remaining_bytes >= 0),
        expire_at REAL,
        CHECK(used_bytes = upload_bytes + download_bytes),
        CHECK(
          remaining_bytes = CASE
            WHEN total_bytes > used_bytes THEN total_bytes - used_bytes
            ELSE 0
          END
        ),
        UNIQUE(subscription_id, observed_at),
        FOREIGN KEY(subscription_id) REFERENCES subscriptions(id),
        FOREIGN KEY(cycle_id) REFERENCES quota_cycles(id)
      )
      """
    )
    try connection.execute(
      """
      CREATE INDEX quota_snapshots_history
      ON quota_snapshots(subscription_id, observed_at DESC)
      """
    )
    try connection.execute(
      """
      CREATE INDEX quota_snapshots_cycle
      ON quota_snapshots(cycle_id, observed_at)
      """
    )
  }

  private static func createQueryStates(_ connection: SQLiteConnection) throws {
    try connection.execute(
      """
      CREATE TABLE quota_query_state (
        subscription_id TEXT PRIMARY KEY,
        last_attempt_at REAL,
        next_attempt_at REAL,
        last_queried_url_fingerprint TEXT,
        consecutive_failures INTEGER NOT NULL CHECK(consecutive_failures >= 0),
        retry_day_start REAL,
        automatic_retry_count INTEGER NOT NULL CHECK(automatic_retry_count >= 0),
        FOREIGN KEY(subscription_id) REFERENCES subscriptions(id)
      )
      """
    )
  }

  private static func createEvents(_ connection: SQLiteConnection) throws {
    try connection.execute(
      """
      CREATE TABLE quota_events (
        id TEXT PRIMARY KEY,
        subscription_id TEXT NOT NULL,
        previous_snapshot_id TEXT NOT NULL,
        current_snapshot_id TEXT NOT NULL,
        occurred_at REAL NOT NULL,
        kind TEXT NOT NULL CHECK(
          kind IN ('usage_reset', 'total_increased', 'total_decreased', 'expiration_changed')
        ),
        is_user_confirmed INTEGER NOT NULL CHECK(is_user_confirmed IN (0, 1)),
        UNIQUE(current_snapshot_id, kind),
        FOREIGN KEY(subscription_id) REFERENCES subscriptions(id),
        FOREIGN KEY(previous_snapshot_id) REFERENCES quota_snapshots(id),
        FOREIGN KEY(current_snapshot_id) REFERENCES quota_snapshots(id)
      )
      """
    )
    try connection.execute(
      """
      CREATE INDEX quota_events_history
      ON quota_events(subscription_id, occurred_at DESC)
      """
    )
  }
}
