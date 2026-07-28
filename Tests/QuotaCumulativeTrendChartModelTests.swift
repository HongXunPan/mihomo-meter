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

  func testNearestPointAndStackedTotalUseRealSnapshotValues() throws {
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
