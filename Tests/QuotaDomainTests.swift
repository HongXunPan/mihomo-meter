import Foundation
import XCTest

@testable import MihomoMeter

final class QuotaDomainTests: XCTestCase {
  func testQuotaTrafficCalculatesUsedAndRemainingBytes() throws {
    let traffic = try QuotaTraffic(
      uploadBytes: 100,
      downloadBytes: 250,
      totalBytes: 1_000
    )

    XCTAssertEqual(traffic.usedBytes, 350)
    XCTAssertEqual(traffic.remainingBytes, 650)
    XCTAssertFalse(traffic.isOverQuota)
  }

  func testQuotaTrafficKeepsRawUsageWhenOverQuota() throws {
    let traffic = try QuotaTraffic(
      uploadBytes: 600,
      downloadBytes: 500,
      totalBytes: 1_000
    )

    XCTAssertEqual(traffic.usedBytes, 1_100)
    XCTAssertEqual(traffic.remainingBytes, 0)
    XCTAssertTrue(traffic.isOverQuota)
  }

  func testQuotaTrafficRejectsZeroTotalAndDatabaseOverflow() {
    XCTAssertThrowsError(
      try QuotaTraffic(uploadBytes: 1, downloadBytes: 2, totalBytes: 0)
    ) { error in
      XCTAssertEqual(error as? QuotaLedgerError, .invalidTotal)
    }
    XCTAssertThrowsError(
      try QuotaTraffic(
        uploadBytes: UInt64(Int64.max),
        downloadBytes: 1,
        totalBytes: UInt64(Int64.max)
      )
    ) { error in
      XCTAssertEqual(error as? QuotaLedgerError, .byteCountOverflow)
    }
  }

  func testTrackedSubscriptionValidatesIdentitySpecificInterval() throws {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    XCTAssertNoThrow(
      try TrackedSubscription(
        id: UUID(),
        name: "当前运行订阅",
        identity: .runtimeSingle,
        createdAt: date,
        updatedAt: date
      )
    )
    XCTAssertThrowsError(
      try TrackedSubscription(
        id: UUID(),
        name: "未配置间隔",
        identity: .clashProfile(uid: "profile-a"),
        createdAt: date,
        updatedAt: date
      )
    ) { error in
      XCTAssertEqual(error as? QuotaLedgerError, .invalidRefreshInterval)
    }
  }

  func testTrendUsesOnlyLatestCycleAndSourceTime() throws {
    let subscriptionID = UUID()
    let previousCycleID = UUID()
    let latestCycleID = UUID()
    let now = Date(timeIntervalSince1970: 1_700_100_000)
    let snapshots = [
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: previousCycleID,
        observedAt: now.addingTimeInterval(-3 * 86_400),
        usedBytes: 700,
        totalBytes: 1_000
      ),
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: latestCycleID,
        observedAt: now.addingTimeInterval(-86_300),
        sourceUpdatedAt: now.addingTimeInterval(-86_400),
        usedBytes: 100,
        totalBytes: 1_000
      ),
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: latestCycleID,
        observedAt: now,
        usedBytes: 300,
        totalBytes: 1_000
      ),
    ]

    let trend = QuotaTrendEngine.calculate(snapshots: snapshots, window: .week, now: now)

    XCTAssertEqual(trend.points.count, 2)
    XCTAssertEqual(trend.points.first?.date, now.addingTimeInterval(-86_400))
    XCTAssertEqual(trend.consumedBytes, 200)
    XCTAssertEqual(trend.dailyConsumptionBytes, 200)
    XCTAssertEqual(trend.estimatedDepletionAt, now.addingTimeInterval(3.5 * 86_400))
  }

  private func snapshot(
    subscriptionID: UUID,
    cycleID: UUID,
    observedAt: Date,
    sourceUpdatedAt: Date? = nil,
    usedBytes: UInt64,
    totalBytes: UInt64
  ) throws -> SubscriptionQuotaSnapshot {
    let traffic = try QuotaTraffic(
      uploadBytes: usedBytes,
      downloadBytes: 0,
      totalBytes: totalBytes
    )
    return SubscriptionQuotaSnapshot(
      id: UUID(),
      cycleID: cycleID,
      observation: QuotaObservation(
        subscriptionID: subscriptionID,
        observedAt: observedAt,
        sourceUpdatedAt: sourceUpdatedAt,
        source: .mihomoRuntime,
        traffic: traffic,
        expireAt: nil
      )
    )
  }
}
