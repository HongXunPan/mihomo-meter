import XCTest

@testable import MihomoMeter

final class TrafficStatisticsPresentationTests: XCTestCase {
  func testSuggestedIntervalNameUsesNextSnapshotPosition() {
    let intervals = [
      makeInterval(name: "已有任务", status: .completed),
      makeInterval(name: "进行中", status: .active),
    ]

    XCTAssertEqual(
      TrafficStatisticsPresentation.suggestedIntervalName(from: intervals),
      "统计任务 3"
    )
  }

  func testQuickPreviewKeepsOnlyFirstThreeActiveIntervals() {
    let intervals = [
      makeInterval(name: "活动一", status: .active),
      makeInterval(name: "已完成", status: .completed),
      makeInterval(name: "活动二", status: .active),
      makeInterval(name: "活动三", status: .active),
      makeInterval(name: "活动四", status: .active),
    ]

    let preview = TrafficStatisticsPresentation.quickActiveIntervals(from: intervals)

    XCTAssertEqual(preview.map(\.name), ["活动一", "活动二", "活动三"])
    XCTAssertEqual(TrafficStatisticsPresentation.additionalActiveCount(from: intervals), 1)
  }

  func testQuickPreviewHasNoAdditionalCountWithinLimit() {
    let intervals = [
      makeInterval(name: "活动一", status: .active),
      makeInterval(name: "已中断", status: .interrupted),
    ]

    XCTAssertEqual(TrafficStatisticsPresentation.additionalActiveCount(from: intervals), 0)
  }

  func testFiltersSeparateActiveAndHistoryIntervals() {
    let intervals = [
      makeInterval(name: "进行中", status: .active),
      makeInterval(name: "已完成", status: .completed),
      makeInterval(name: "已中断", status: .interrupted),
    ]

    XCTAssertEqual(
      TrafficStatisticsFilter.active.intervals(from: intervals).map(\.name),
      ["进行中"]
    )
    XCTAssertEqual(
      TrafficStatisticsFilter.history.intervals(from: intervals).map(\.name),
      ["已完成", "已中断"]
    )
    XCTAssertEqual(TrafficStatisticsFilter.all.intervals(from: intervals), intervals)
  }

  private func makeInterval(
    name: String,
    status: TrafficIntervalStatus
  ) -> TrafficInterval {
    TrafficInterval(
      id: UUID(),
      name: name,
      note: nil,
      status: status,
      startedAt: Date(timeIntervalSince1970: 1_000),
      endedAt: status == .active ? nil : Date(timeIntervalSince1970: 2_000),
      endReason: status == .active ? nil : .user,
      proxyUsage: TrafficBytes(upload: 1_000, download: 2_000)
    )
  }
}
