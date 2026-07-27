import Foundation
import SQLite3
import XCTest

@testable import MihomoMeter

final class SQLiteQuotaLedgerTests: SQLiteQuotaLedgerTestCase {
  func testPersistsSubscriptionSnapshotsAndTrendAcrossConnections() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let start = Date(timeIntervalSince1970: 1_700_200_000)
    let later = start.addingTimeInterval(86_400)
    let subscription = try runtimeSubscription(at: start)
    let ledger = SQLiteQuotaLedger(databaseURL: database)

    try await ledger.prepare()
    _ = try await ledger.upsertSubscription(subscription)
    _ = try await ledger.record(
      observation(
        subscriptionID: subscription.id,
        at: start,
        source: .mihomoRuntime,
        usedBytes: 300,
        totalBytes: 1_000
      )
    )
    _ = try await ledger.record(
      observation(
        subscriptionID: subscription.id,
        at: later,
        source: .mihomoRuntime,
        usedBytes: 500,
        totalBytes: 1_000
      )
    )

    let reopened = SQLiteQuotaLedger(databaseURL: database)
    try await reopened.prepare()
    let reopenedSubscriptions = try await reopened.subscriptions()
    let latestRemainingBytes =
      try await reopened.latestSnapshot(for: subscription.id)?.traffic.remainingBytes
    XCTAssertEqual(reopenedSubscriptions, [subscription])
    XCTAssertEqual(latestRemainingBytes, 500)
    let trend = try await reopened.trend(
      for: subscription.id,
      window: .week,
      now: later
    )
    XCTAssertEqual(trend.consumedBytes, 200)
    XCTAssertEqual(trend.dailyConsumptionBytes, 200)
    XCTAssertEqual(trend.estimatedDepletionAt, later.addingTimeInterval(2.5 * 86_400))
  }

  func testUsageResetStartsUnconfirmedCycleWithoutCrossCycleTrend() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let start = Date(timeIntervalSince1970: 1_700_300_000)
    let subscription = try runtimeSubscription(at: start)
    let ledger = SQLiteQuotaLedger(databaseURL: database)

    _ = try await ledger.upsertSubscription(subscription)
    _ = try await ledger.record(
      observation(
        subscriptionID: subscription.id,
        at: start,
        source: .mihomoRuntime,
        usedBytes: 100,
        totalBytes: 1_000
      )
    )
    _ = try await ledger.record(
      observation(
        subscriptionID: subscription.id,
        at: start.addingTimeInterval(100),
        source: .mihomoRuntime,
        usedBytes: 300,
        totalBytes: 1_000
      )
    )
    _ = try await ledger.record(
      observation(
        subscriptionID: subscription.id,
        at: start.addingTimeInterval(200),
        source: .mihomoRuntime,
        usedBytes: 20,
        totalBytes: 1_000
      )
    )

    let cycles = try await ledger.cycles(for: subscription.id)
    XCTAssertEqual(cycles.count, 2)
    XCTAssertEqual(cycles.first?.startReason, .usageReset)
    XCTAssertEqual(cycles.first?.isUserConfirmed, false)
    XCTAssertNil(cycles.first?.endedAt)
    XCTAssertEqual(cycles.last?.startReason, .initial)
    XCTAssertEqual(cycles.last?.endedAt, start.addingTimeInterval(200))

    let trend = try await ledger.trend(
      for: subscription.id,
      window: .day,
      now: start.addingTimeInterval(200)
    )
    XCTAssertEqual(trend.points.count, 1)
    XCTAssertNil(trend.dailyConsumptionBytes)
    XCTAssertNil(trend.estimatedDepletionAt)
  }

  func testRejectsMismatchedSourceAndNonMonotonicObservation() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let start = Date(timeIntervalSince1970: 1_700_400_000)
    let subscription = try runtimeSubscription(at: start)
    let ledger = SQLiteQuotaLedger(databaseURL: database)

    _ = try await ledger.upsertSubscription(subscription)
    do {
      _ = try await ledger.record(
        observation(
          subscriptionID: subscription.id,
          at: start,
          source: .meterActiveQuery,
          usedBytes: 100,
          totalBytes: 1_000
        )
      )
      XCTFail("运行时订阅不应接受主动查询来源")
    } catch {
      XCTAssertEqual(error as? QuotaLedgerError, .sourceMismatch)
    }

    _ = try await ledger.record(
      observation(
        subscriptionID: subscription.id,
        at: start,
        source: .mihomoRuntime,
        usedBytes: 100,
        totalBytes: 1_000
      )
    )
    do {
      _ = try await ledger.record(
        observation(
          subscriptionID: subscription.id,
          at: start,
          source: .mihomoRuntime,
          usedBytes: 120,
          totalBytes: 1_000
        )
      )
      XCTFail("相同观测时间不应重复写入")
    } catch {
      XCTAssertEqual(error as? QuotaLedgerError, .nonMonotonicObservation)
    }
  }

  func testSubscriptionSchemaStoresFingerprintButNoURLColumn() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let date = Date(timeIntervalSince1970: 1_700_500_000)
    let subscription = try profileSubscription(at: date)
    let ledger = SQLiteQuotaLedger(databaseURL: database)

    let stored = try await ledger.upsertSubscription(subscription)

    XCTAssertEqual(stored.urlFingerprint, "fingerprint-test")
    let columns = try subscriptionColumnNames(in: database)
    XCTAssertTrue(columns.contains("url_fingerprint"))
    XCTAssertFalse(columns.contains("url"))
    XCTAssertFalse(columns.contains("subscription_url"))
  }

  func testRenamesProfileButRejectsIdentityReplacement() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let start = Date(timeIntervalSince1970: 1_700_550_000)
    let subscription = try profileSubscription(at: start)
    let ledger = SQLiteQuotaLedger(databaseURL: database)
    _ = try await ledger.upsertSubscription(subscription)

    let renamed = try TrackedSubscription(
      id: subscription.id,
      name: "改名后的 Profile",
      identity: subscription.identity,
      urlFingerprint: "fingerprint-updated",
      refreshIntervalMinutes: 360,
      createdAt: start,
      updatedAt: start.addingTimeInterval(60)
    )
    let stored = try await ledger.upsertSubscription(renamed)
    XCTAssertEqual(stored.name, "改名后的 Profile")
    XCTAssertEqual(stored.urlFingerprint, "fingerprint-updated")

    let replacement = try TrackedSubscription(
      id: subscription.id,
      name: "另一个 Profile",
      identity: .clashProfile(uid: "profile-replacement"),
      refreshIntervalMinutes: 360,
      createdAt: start,
      updatedAt: start.addingTimeInterval(120)
    )
    do {
      _ = try await ledger.upsertSubscription(replacement)
      XCTFail("Profile UID 变化不应静默继承原历史")
    } catch {
      XCTAssertEqual(error as? QuotaLedgerError, .identityChangeRequiresMigration)
    }
  }

  func testRejectsUnsupportedQuotaSchema() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    do {
      let connection = try SQLiteConnection(fileURL: database)
      try connection.execute("PRAGMA user_version = 3")
      connection.close()
    }

    let ledger = SQLiteQuotaLedger(databaseURL: database)
    do {
      try await ledger.prepare()
      XCTFail("不应打开未来版本的配额数据库")
    } catch {
      XCTAssertEqual(error as? QuotaLedgerError, .unsupportedSchema(3))
    }
  }

  func testPersistsSanitizedQueryStateAcrossConnections() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let date = Date(timeIntervalSince1970: 1_700_600_000)
    let subscription = try profileSubscription(at: date)
    let ledger = SQLiteQuotaLedger(databaseURL: database)
    _ = try await ledger.upsertSubscription(subscription)

    let state = ProfileQuotaQueryState(
      subscriptionID: subscription.id,
      lastAttemptAt: date,
      nextAttemptAt: date.addingTimeInterval(300),
      lastQueriedURLFingerprint: "fingerprint-test",
      consecutiveFailures: 1,
      retryDayStart: Calendar.current.startOfDay(for: date),
      automaticRetryCount: 0
    )
    try await ledger.saveProfileQueryState(state)

    let reopened = SQLiteQuotaLedger(databaseURL: database)
    let reopenedState = try await reopened.profileQueryState(for: subscription.id)
    XCTAssertEqual(reopenedState, state)

    let connection = try SQLiteConnection(fileURL: database)
    let columns = try queryStateColumnNames(connection)
    XCTAssertTrue(columns.contains("last_queried_url_fingerprint"))
    XCTAssertFalse(columns.contains("url"))
    XCTAssertFalse(columns.contains("error_message"))
  }

  func testMigratesVersionOneDatabaseToQueryStateSchema() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    do {
      let connection = try SQLiteConnection(fileURL: database)
      try connection.execute("CREATE TABLE subscriptions (id TEXT PRIMARY KEY)")
      try connection.execute("PRAGMA user_version = 1")
      connection.close()
    }

    let ledger = SQLiteQuotaLedger(databaseURL: database)
    try await ledger.prepare()

    let connection = try SQLiteConnection(fileURL: database)
    let versionStatement = try connection.prepare("PRAGMA user_version")
    XCTAssertEqual(try versionStatement.step(), SQLITE_ROW)
    XCTAssertEqual(versionStatement.int64(at: 0), 2)
    XCTAssertTrue(try queryStateColumnNames(connection).contains("next_attempt_at"))
  }

  func testQuotaDatabaseUsesIndependentLocation() {
    let quotaURL = QuotaLedgerLocation.defaultDatabaseURL()
    let trafficURL = TrafficLedgerLocation.defaultDatabaseURL()

    XCTAssertEqual(quotaURL.lastPathComponent, "quota.sqlite3")
    XCTAssertEqual(trafficURL.lastPathComponent, "traffic.sqlite3")
    XCTAssertNotEqual(quotaURL, trafficURL)
  }

  private func queryStateColumnNames(_ connection: SQLiteConnection) throws -> [String] {
    let statement = try connection.prepare("PRAGMA table_info(quota_query_state)")
    var columns: [String] = []
    while try statement.step() == SQLITE_ROW {
      if let name = statement.text(at: 1) {
        columns.append(name)
      }
    }
    return columns
  }
}
