import Foundation
import XCTest

@testable import MihomoMeter

final class QuotaUsageTrendTests: XCTestCase {
  func testAggregatesHourlySnapshotDeltasIntoOneDailyBar() throws {
    let calendar = utcCalendar()
    let subscriptionID = UUID()
    let cycleID = UUID()
    let start = Date(timeIntervalSince1970: 1_704_067_200)
    let snapshots = try (0...24).map { hour in
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: cycleID,
        at: start.addingTimeInterval(TimeInterval(hour) * 3_600),
        uploadBytes: UInt64(hour) * 10,
        downloadBytes: UInt64(hour) * 100
      )
    }

    let series = QuotaUsageTrendEngine.calculate(
      snapshots: snapshots,
      windowStart: start,
      windowEnd: start.addingTimeInterval(24 * 3_600),
      calendar: calendar
    )[.day]

    let bar = try XCTUnwrap(series?.bars.first)
    XCTAssertEqual(series?.bars.count, 1)
    XCTAssertEqual(bar.uploadBytes, 240)
    XCTAssertEqual(bar.downloadBytes, 2_400)
    XCTAssertEqual(bar.intervalCount, 24)
    XCTAssertFalse(bar.isBoundaryApproximation)
  }

  func testKeepsFortyEightHourDeltaAsUnresolvedDailyInterval() throws {
    let calendar = utcCalendar()
    let subscriptionID = UUID()
    let cycleID = UUID()
    let start = Date(timeIntervalSince1970: 1_704_070_800)
    let end = start.addingTimeInterval(48 * 3_600)
    let snapshots = [
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: cycleID,
        at: start,
        uploadBytes: 100,
        downloadBytes: 1_000
      ),
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: cycleID,
        at: end,
        uploadBytes: 500,
        downloadBytes: 3_000
      ),
    ]

    let series = try XCTUnwrap(
      QuotaUsageTrendEngine.calculate(
        snapshots: snapshots,
        windowStart: start,
        windowEnd: end,
        calendar: calendar
      )[.day]
    )

    XCTAssertTrue(series.bars.isEmpty)
    XCTAssertEqual(series.unresolvedIntervals.count, 1)
    XCTAssertEqual(series.unresolvedIntervals.first?.uploadBytes, 400)
    XCTAssertEqual(series.unresolvedIntervals.first?.downloadBytes, 2_000)
    XCTAssertFalse(series.isAvailable)
  }

  func testCalculatesUsageWithinEachCycleWithoutCrossCycleDelta() throws {
    let calendar = utcCalendar()
    let subscriptionID = UUID()
    let firstCycleID = UUID()
    let secondCycleID = UUID()
    let start = Date(timeIntervalSince1970: 1_704_067_200)
    let snapshots = [
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: firstCycleID,
        at: start,
        uploadBytes: 100,
        downloadBytes: 1_000
      ),
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: firstCycleID,
        at: start.addingTimeInterval(24 * 3_600),
        uploadBytes: 200,
        downloadBytes: 1_500
      ),
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: secondCycleID,
        at: start.addingTimeInterval(2 * 24 * 3_600),
        uploadBytes: 10,
        downloadBytes: 100
      ),
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: secondCycleID,
        at: start.addingTimeInterval(3 * 24 * 3_600),
        uploadBytes: 60,
        downloadBytes: 300
      ),
    ]

    let series = try XCTUnwrap(
      QuotaUsageTrendEngine.calculate(
        snapshots: snapshots,
        windowStart: start,
        windowEnd: start.addingTimeInterval(3 * 24 * 3_600),
        calendar: calendar
      )[.day]
    )

    XCTAssertEqual(series.bars.count, 2)
    XCTAssertEqual(series.totalUploadBytes, 150)
    XCTAssertEqual(series.totalDownloadBytes, 700)
  }

  func testDoesNotExposeHourlyAggregationForSixHourSnapshots() throws {
    let calendar = utcCalendar()
    let subscriptionID = UUID()
    let cycleID = UUID()
    let start = Date(timeIntervalSince1970: 1_704_067_200)
    let snapshots = try (0...4).map { index in
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: cycleID,
        at: start.addingTimeInterval(TimeInterval(index) * 6 * 3_600),
        uploadBytes: UInt64(index) * 50,
        downloadBytes: UInt64(index) * 500
      )
    }

    let series = try XCTUnwrap(
      QuotaUsageTrendEngine.calculate(
        snapshots: snapshots,
        windowStart: start,
        windowEnd: start.addingTimeInterval(24 * 3_600),
        calendar: calendar
      )[.hour]
    )

    XCTAssertTrue(series.bars.isEmpty)
    XCTAssertEqual(series.unresolvedIntervals.count, 4)
    XCTAssertFalse(series.isAvailable)
  }

  func testAutomaticAggregationUsesNaturalSixHourBucketForFiveHourInterval() throws {
    let calendar = utcCalendar()
    let subscriptionID = UUID()
    let cycleID = UUID()
    let start = Date(timeIntervalSince1970: 1_704_081_840)
    let next = start.addingTimeInterval(5 * 3_600 + 5 * 60)
    let snapshots = [
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: cycleID,
        at: start,
        uploadBytes: 100,
        downloadBytes: 1_000
      ),
      try snapshot(
        subscriptionID: subscriptionID,
        cycleID: cycleID,
        at: next,
        uploadBytes: 180,
        downloadBytes: 1_500
      ),
    ]

    let series = try XCTUnwrap(
      QuotaUsageTrendEngine.calculate(
        snapshots: snapshots,
        windowStart: start,
        windowEnd: start.addingTimeInterval(24 * 3_600),
        calendar: calendar
      )[.automatic]
    )

    XCTAssertEqual(series.resolvedAggregation, .sixHour)
    XCTAssertEqual(series.bars.count, 1)
    XCTAssertEqual(series.totalUploadBytes, 80)
    XCTAssertEqual(series.totalDownloadBytes, 500)
    XCTAssertTrue(series.bars[0].isBoundaryApproximation)
  }

  private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
  }

  private func snapshot(
    subscriptionID: UUID,
    cycleID: UUID,
    at date: Date,
    uploadBytes: UInt64,
    downloadBytes: UInt64
  ) throws -> SubscriptionQuotaSnapshot {
    SubscriptionQuotaSnapshot(
      id: UUID(),
      cycleID: cycleID,
      observation: QuotaObservation(
        subscriptionID: subscriptionID,
        observedAt: date,
        sourceUpdatedAt: nil,
        source: .mihomoRuntime,
        traffic: try QuotaTraffic(
          uploadBytes: uploadBytes,
          downloadBytes: downloadBytes,
          totalBytes: 10_000
        ),
        expireAt: nil
      )
    )
  }
}
