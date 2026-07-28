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

    let trend = QuotaTrendEngine.calculate(
      snapshots: snapshots,
      window: .week,
      now: now,
      context: QuotaTrendContext(
        latestSnapshot: snapshots.last,
        currentCycle: QuotaCycle(
          id: latestCycleID,
          subscriptionID: subscriptionID,
          startedAt: now.addingTimeInterval(-86_400),
          startReason: .initial,
          isUserConfirmed: true
        ),
        maximumDataAge: 86_400
      )
    )

    XCTAssertEqual(trend.points.count, 2)
    XCTAssertEqual(trend.points.first?.date, now.addingTimeInterval(-86_400))
    XCTAssertEqual(trend.segments.map(\.cycleID), [previousCycleID, latestCycleID])
    XCTAssertEqual(trend.segments.map(\.points.count), [1, 2])
    XCTAssertEqual(trend.consumedBytes, 200)
    XCTAssertEqual(trend.dailyConsumptionBytes, 200)
    XCTAssertEqual(trend.estimatedDepletionAt, now.addingTimeInterval(3.5 * 86_400))
  }

  func testTrendSuppressesForecastWhenObservationSpanIsTooShort() throws {
    let context = try trendContext(
      firstOffset: -5 * 60 * 60,
      latestOffset: 0,
      isCycleConfirmed: true
    )

    let trend = QuotaTrendEngine.calculate(
      snapshots: context.snapshots,
      window: .day,
      now: context.now,
      context: context.trendContext
    )

    XCTAssertEqual(
      trend.depletionForecast,
      .unavailable(.insufficientObservationSpan)
    )
  }

  func testTrendSuppressesForecastForStaleDataAndUnconfirmedCycle() throws {
    let stale = try trendContext(
      firstOffset: -48 * 60 * 60,
      latestOffset: -25 * 60 * 60,
      isCycleConfirmed: true
    )
    let staleTrend = QuotaTrendEngine.calculate(
      snapshots: stale.snapshots,
      window: .week,
      now: stale.now,
      context: stale.trendContext
    )
    XCTAssertEqual(staleTrend.depletionForecast, .unavailable(.staleData))

    let unconfirmed = try trendContext(
      firstOffset: -12 * 60 * 60,
      latestOffset: 0,
      isCycleConfirmed: false
    )
    let unconfirmedTrend = QuotaTrendEngine.calculate(
      snapshots: unconfirmed.snapshots,
      window: .day,
      now: unconfirmed.now,
      context: unconfirmed.trendContext
    )
    XCTAssertEqual(
      unconfirmedTrend.depletionForecast,
      .unavailable(.unconfirmedCycle)
    )
  }

  func testTrendForecastStartsFromLatestEffectiveObservation() throws {
    let context = try trendContext(
      firstOffset: -24 * 60 * 60,
      latestOffset: -12 * 60 * 60,
      isCycleConfirmed: true
    )

    let trend = QuotaTrendEngine.calculate(
      snapshots: context.snapshots,
      window: .week,
      now: context.now,
      context: context.trendContext
    )

    let latestDate = try XCTUnwrap(context.snapshots.last?.effectiveAt)
    XCTAssertEqual(
      trend.estimatedDepletionAt,
      latestDate.addingTimeInterval(1.75 * 86_400)
    )
  }

  private func trendContext(
    firstOffset: TimeInterval,
    latestOffset: TimeInterval,
    isCycleConfirmed: Bool
  ) throws -> QuotaTrendTestContext {
    let subscriptionID = UUID()
    let cycleID = UUID()
    let now = Date(timeIntervalSince1970: 1_700_800_000)
    let snapshots = [
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: cycleID,
        observedAt: now.addingTimeInterval(firstOffset),
        usedBytes: 100,
        totalBytes: 1_000
      ),
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: cycleID,
        observedAt: now.addingTimeInterval(latestOffset),
        usedBytes: 300,
        totalBytes: 1_000
      ),
    ]
    return QuotaTrendTestContext(
      now: now,
      snapshots: snapshots,
      trendContext: QuotaTrendContext(
        latestSnapshot: snapshots.last,
        currentCycle: QuotaCycle(
          id: cycleID,
          subscriptionID: subscriptionID,
          startedAt: snapshots[0].effectiveAt,
          startReason: .initial,
          isUserConfirmed: isCycleConfirmed
        ),
        maximumDataAge: 24 * 60 * 60
      )
    )
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

private struct QuotaTrendTestContext {
  let now: Date
  let snapshots: [SubscriptionQuotaSnapshot]
  let trendContext: QuotaTrendContext
}
