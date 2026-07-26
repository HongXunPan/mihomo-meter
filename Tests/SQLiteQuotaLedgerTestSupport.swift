import Foundation
import SQLite3
import XCTest

@testable import MihomoMeter

class SQLiteQuotaLedgerTestCase: XCTestCase {
  func temporaryDatabase() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("MihomoMeterQuotaTests-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("quota.sqlite3")
  }

  func removeDatabase(at url: URL) {
    try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
  }

  func runtimeSubscription(
    id: UUID = UUID(),
    name: String = "当前运行订阅",
    at date: Date
  ) throws -> TrackedSubscription {
    try TrackedSubscription(
      id: id,
      name: name,
      identity: .runtimeSingle,
      createdAt: date,
      updatedAt: date
    )
  }

  func profileSubscription(
    id: UUID = UUID(),
    name: String = "测试 Profile",
    uid: String = "profile-test",
    intervalMinutes: Int = 360,
    at date: Date
  ) throws -> TrackedSubscription {
    try TrackedSubscription(
      id: id,
      name: name,
      identity: .clashProfile(uid: uid),
      urlFingerprint: "fingerprint-test",
      refreshIntervalMinutes: intervalMinutes,
      createdAt: date,
      updatedAt: date
    )
  }

  func observation(
    subscriptionID: UUID,
    at date: Date,
    source: QuotaObservationSource,
    usedBytes: UInt64,
    totalBytes: UInt64
  ) throws -> QuotaObservation {
    QuotaObservation(
      subscriptionID: subscriptionID,
      observedAt: date,
      sourceUpdatedAt: nil,
      source: source,
      traffic: try QuotaTraffic(
        uploadBytes: usedBytes,
        downloadBytes: 0,
        totalBytes: totalBytes
      ),
      expireAt: nil
    )
  }

  func subscriptionColumnNames(in databaseURL: URL) throws -> [String] {
    let connection = try SQLiteConnection(fileURL: databaseURL)
    let statement = try connection.prepare("PRAGMA table_info(subscriptions)")
    var columns: [String] = []
    while try statement.step() == SQLITE_ROW {
      if let name = statement.text(at: 1) {
        columns.append(name)
      }
    }
    return columns
  }
}
