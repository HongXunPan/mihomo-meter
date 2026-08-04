import Foundation
import XCTest

@testable import MihomoMeter

final class QuotaCumulativeTrendChartModelTests: XCTestCase {
  func testTargetPointCountFollowsPlotWidthAndLimits() {
    XCTAssertEqual(QuotaCumulativeTrendChartModel.targetPointCount(for: 20), 2)
    XCTAssertEqual(QuotaCumulativeTrendChartModel.targetPointCount(for: 400), 10)
    XCTAssertEqual(QuotaCumulativeTrendChartModel.targetPointCount(for: 2_000), 30)
  }

  func testSamplingKeepsEndpointsAndChoosesPointsNearEvenTargets() throws {
    let cycleID = UUID()
    let points = try (0..<10).map { index in
      try point(
        at: Double(index) * 3_600,
        uploadBytes: UInt64(index * 10),
        downloadBytes: UInt64(index * 20)
      )
    }
    let model = QuotaCumulativeTrendChartModel(
      segments: [QuotaTrendSegment(cycleID: cycleID, points: points)],
      targetPointCount: 4
    )

    XCTAssertEqual(model.sourcePointCount, 10)
    XCTAssertEqual(
      model.points.map(\.point.date),
      [
        points[0].date,
        points[3].date,
        points[6].date,
        points[9].date,
      ]
    )
    XCTAssertEqual(model.dateDomain, points[0].date...points[9].date)
  }

  func testSamplingKeepsEveryCycleEndpointBeyondRequestedCount() throws {
    let firstCycle = try segment(
      offsets: [0, 100, 200],
      uploadBase: 10,
      downloadBase: 20
    )
    let secondCycle = try segment(
      offsets: [300, 400, 500],
      uploadBase: 5,
      downloadBase: 15
    )
    let model = QuotaCumulativeTrendChartModel(
      segments: [firstCycle, secondCycle],
      targetPointCount: 2
    )

    XCTAssertEqual(model.segments.count, 2)
    XCTAssertEqual(model.segments.map(\.points.count), [2, 2])
    XCTAssertEqual(model.points.count, 4)
    XCTAssertNil(model.segments[0].points[0].delta)
    XCTAssertNil(model.segments[1].points[0].delta)
    XCTAssertEqual(model.segments[0].points[1].delta?.uploadBytes, 20)
    XCTAssertEqual(model.segments[0].points[1].delta?.downloadBytes, 40)
  }

  func testDeltaUsesPreviousDisplayedPointInsteadOfHiddenSnapshot() throws {
    let points = try (0..<5).map { index in
      try point(
        at: Double(index) * 60,
        uploadBytes: UInt64(index * 100),
        downloadBytes: UInt64(index * 200)
      )
    }
    let model = QuotaCumulativeTrendChartModel(
      segments: [QuotaTrendSegment(cycleID: UUID(), points: points)],
      targetPointCount: 2
    )
    let lastPoint = try XCTUnwrap(model.points.last)

    XCTAssertEqual(model.points.count, 2)
    XCTAssertEqual(lastPoint.previousPoint?.id, points.first?.id)
    XCTAssertEqual(lastPoint.delta?.uploadBytes, 400)
    XCTAssertEqual(lastPoint.delta?.downloadBytes, 800)
    XCTAssertEqual(lastPoint.delta?.totalBytes, 1_200)
    XCTAssertEqual(lastPoint.delta?.duration, 240)
  }

  func testCounterRegressionSplitsDisplaySegment() throws {
    let points = [
      try point(at: 0, uploadBytes: 100, downloadBytes: 200),
      try point(at: 60, uploadBytes: 150, downloadBytes: 250),
      try point(at: 120, uploadBytes: 140, downloadBytes: 300),
    ]
    let model = QuotaCumulativeTrendChartModel(
      segments: [QuotaTrendSegment(cycleID: UUID(), points: points)],
      targetPointCount: 30
    )

    XCTAssertEqual(model.segments.count, 2)
    XCTAssertEqual(model.segments[0].breakReason, .cycleStart)
    XCTAssertEqual(model.segments[1].breakReason, .counterRegression)
    XCTAssertEqual(model.segments[0].points.count, 2)
    XCTAssertEqual(model.segments[1].points.count, 1)
    XCTAssertNil(model.segments[1].points[0].previousPoint)
    XCTAssertNil(model.segments[1].points[0].delta)
  }

  func testNearestPointAndTotalUseRealSnapshotValues() throws {
    let points = [
      try point(at: 0, uploadBytes: 10, downloadBytes: 20),
      try point(at: 120, uploadBytes: 30, downloadBytes: 70),
    ]
    let model = QuotaCumulativeTrendChartModel(
      segments: [QuotaTrendSegment(cycleID: UUID(), points: points)],
      targetPointCount: 30
    )
    let nearest = try XCTUnwrap(
      model.nearestPoint(to: baseDate.addingTimeInterval(100))
    )

    XCTAssertEqual(nearest.id, points[1].id)
    for displayPoint in model.points {
      XCTAssertEqual(
        displayPoint.point.traffic.usedBytes,
        displayPoint.point.traffic.uploadBytes
          + displayPoint.point.traffic.downloadBytes
      )
    }
  }

  func testNormalizedPositionClampsAndChoosesNearestRealPoint() throws {
    let points = [
      try point(at: 0, uploadBytes: 10, downloadBytes: 20),
      try point(at: 60, uploadBytes: 20, downloadBytes: 40),
      try point(at: 120, uploadBytes: 30, downloadBytes: 60),
    ]
    let model = QuotaCumulativeTrendChartModel(
      segments: [QuotaTrendSegment(cycleID: UUID(), points: points)],
      targetPointCount: 30
    )

    XCTAssertEqual(model.nearestPoint(atNormalizedPosition: -1)?.id, points[0].id)
    XCTAssertEqual(model.nearestPoint(atNormalizedPosition: 0.6)?.id, points[1].id)
    XCTAssertEqual(model.nearestPoint(atNormalizedPosition: 2)?.id, points[2].id)
  }

  func testAreaValuesStackRangeIncrementsToActualTotal() throws {
    let points = [
      try point(at: 0, uploadBytes: 10, downloadBytes: 20),
      try point(at: 120, uploadBytes: 30, downloadBytes: 70),
    ]
    let model = QuotaCumulativeTrendChartModel(
      segments: [QuotaTrendSegment(cycleID: UUID(), points: points)],
      targetPointCount: 30
    )
    let lastPoint = try XCTUnwrap(model.points.last)
    let values = QuotaCumulativeTrendAreaValues(displayPoint: lastPoint)

    XCTAssertEqual(values.baseline, 30)
    XCTAssertEqual(values.downloadEnd, 80)
    XCTAssertEqual(values.total, 100)
    XCTAssertEqual(values.downloadEnd - values.baseline, 50)
    XCTAssertEqual(values.total - values.downloadEnd, 20)
  }

  func testTotalUsageDomainUsesRangeExtremaWithoutForcingZero() throws {
    let points = [
      try point(at: 0, uploadBytes: 100, downloadBytes: 200),
      try point(at: 60, uploadBytes: 160, downloadBytes: 260),
    ]
    let model = QuotaCumulativeTrendChartModel(
      segments: [QuotaTrendSegment(cycleID: UUID(), points: points)],
      targetPointCount: 30
    )
    let domain = try XCTUnwrap(model.totalUsageDomain)

    XCTAssertEqual(domain.lowerBound, 294, accuracy: 0.001)
    XCTAssertEqual(domain.upperBound, 426, accuracy: 0.001)
    XCTAssertGreaterThan(domain.lowerBound, 0)
  }

  func testTotalUsageDomainExpandsConstantValues() throws {
    let points = [
      try point(at: 0, uploadBytes: 100, downloadBytes: 200),
      try point(at: 60, uploadBytes: 100, downloadBytes: 200),
    ]
    let model = QuotaCumulativeTrendChartModel(
      segments: [QuotaTrendSegment(cycleID: UUID(), points: points)],
      targetPointCount: 30
    )
    let domain = try XCTUnwrap(model.totalUsageDomain)

    XCTAssertEqual(domain.lowerBound, 297, accuracy: 0.001)
    XCTAssertEqual(domain.upperBound, 303, accuracy: 0.001)
  }

  func testRangeUsageSumsComparableIntervalsWithoutCrossingCycles() throws {
    let firstCycle = QuotaTrendSegment(
      cycleID: UUID(),
      points: [
        try point(at: 0, uploadBytes: 10, downloadBytes: 20),
        try point(at: 60, uploadBytes: 30, downloadBytes: 70),
      ]
    )
    let secondCycle = QuotaTrendSegment(
      cycleID: UUID(),
      points: [
        try point(at: 120, uploadBytes: 5, downloadBytes: 10),
        try point(at: 180, uploadBytes: 8, downloadBytes: 25),
      ]
    )
    let usage = QuotaCumulativeTrendRangeUsage(
      segments: [firstCycle, secondCycle]
    )

    XCTAssertTrue(usage.isAvailable)
    XCTAssertEqual(usage.comparableIntervalCount, 2)
    XCTAssertEqual(usage.traffic.upload, 23)
    XCTAssertEqual(usage.traffic.download, 65)
    XCTAssertEqual(usage.traffic.total, 88)
  }

  func testRangeUsageSkipsRegressionAndContinuesFromNewBaseline() throws {
    let points = [
      try point(at: 0, uploadBytes: 100, downloadBytes: 200),
      try point(at: 60, uploadBytes: 120, downloadBytes: 240),
      try point(at: 120, uploadBytes: 10, downloadBytes: 20),
      try point(at: 180, uploadBytes: 15, downloadBytes: 35),
    ]
    let usage = QuotaCumulativeTrendRangeUsage(
      segments: [QuotaTrendSegment(cycleID: UUID(), points: points)]
    )

    XCTAssertEqual(usage.comparableIntervalCount, 2)
    XCTAssertEqual(usage.traffic.upload, 25)
    XCTAssertEqual(usage.traffic.download, 55)
    XCTAssertEqual(usage.traffic.total, 80)
  }

  func testRelativeDateUsesChinesePresentation() {
    let text = SubscriptionQuotaFormatter.relativeDate(
      baseDate.addingTimeInterval(30 * 60),
      relativeTo: baseDate
    )

    XCTAssertTrue(text.contains("后"))
    XCTAssertFalse(text.contains("in"))
  }

  func testTrendComparisonOmitsRepeatedCurrentTimestamp() {
    let previousDate = baseDate
    let currentDate = baseDate.addingTimeInterval(2 * 3_600)

    let text = SubscriptionQuotaFormatter.trendComparison(
      from: previousDate,
      to: currentDate
    )

    XCTAssertTrue(text.hasPrefix("较 "))
    XCTAssertTrue(text.contains(" · 间隔 "))
    XCTAssertFalse(
      text.contains(SubscriptionQuotaFormatter.trendInspectorTimestamp(currentDate))
    )
  }

  func testTrendComparisonIncludesDateWhenCrossingDay() {
    let calendar = Calendar.autoupdatingCurrent
    let startOfDay = calendar.startOfDay(for: baseDate)
    let sameDayPreviousDate = startOfDay.addingTimeInterval(10 * 3_600)
    let previousDate = startOfDay.addingTimeInterval(23 * 3_600)
    let currentDate = startOfDay.addingTimeInterval(25 * 3_600)

    let sameDayText = SubscriptionQuotaFormatter.trendComparison(
      from: sameDayPreviousDate,
      to: startOfDay.addingTimeInterval(12 * 3_600)
    )
    let crossDayText = SubscriptionQuotaFormatter.trendComparison(
      from: previousDate,
      to: currentDate
    )

    XCTAssertFalse(
      sameDayText.contains(
        SubscriptionQuotaFormatter.trendInspectorTimestamp(sameDayPreviousDate)
      )
    )
    XCTAssertTrue(
      crossDayText.contains(
        SubscriptionQuotaFormatter.trendInspectorTimestamp(previousDate)
      )
    )
  }

  private func segment(
    offsets: [TimeInterval],
    uploadBase: UInt64,
    downloadBase: UInt64
  ) throws -> QuotaTrendSegment {
    let points = try offsets.enumerated().map { index, offset in
      try point(
        at: offset,
        uploadBytes: uploadBase + UInt64(index * 10),
        downloadBytes: downloadBase + UInt64(index * 20)
      )
    }
    return QuotaTrendSegment(cycleID: UUID(), points: points)
  }

  private func point(
    at offset: TimeInterval,
    uploadBytes: UInt64,
    downloadBytes: UInt64
  ) throws -> QuotaTrendPoint {
    QuotaTrendPoint(
      id: UUID(),
      date: baseDate.addingTimeInterval(offset),
      traffic: try QuotaTraffic(
        uploadBytes: uploadBytes,
        downloadBytes: downloadBytes,
        totalBytes: 10_000
      )
    )
  }

  private var baseDate: Date {
    Date(timeIntervalSince1970: 1_700_000_000)
  }
}
