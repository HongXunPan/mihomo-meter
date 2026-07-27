import Foundation
import SQLite3

final class QuotaLedgerPersistence {
  private let connection: SQLiteConnection

  var subscriptions: QuotaSubscriptionPersistence {
    QuotaSubscriptionPersistence(persistence: self)
  }

  var snapshots: QuotaSnapshotPersistence {
    QuotaSnapshotPersistence(persistence: self)
  }

  var cycles: QuotaCyclePersistence {
    QuotaCyclePersistence(persistence: self)
  }

  var queryStates: ProfileQuotaQueryStatePersistence {
    ProfileQuotaQueryStatePersistence(persistence: self)
  }

  var changeCount: Int32 {
    sqlite3_changes(connection.handle)
  }

  init(databaseURL: URL) throws {
    connection = try SQLiteConnection(fileURL: databaseURL)
    try QuotaLedgerSchema.migrate(connection)
  }

  func transaction<Result>(_ body: () throws -> Result) throws -> Result {
    try connection.transaction(body)
  }

  func prepare(_ sql: String) throws -> SQLiteStatement {
    try connection.prepare(sql)
  }
}
