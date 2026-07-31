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

  func testActiveIntervalSummaryCountsEveryRunningTask() {
    let intervals = [
      makeInterval(name: "活动一", status: .active),
      makeInterval(name: "已完成", status: .completed),
      makeInterval(name: "活动二", status: .active),
      makeInterval(name: "活动三", status: .active),
      makeInterval(name: "活动四", status: .active),
    ]

    XCTAssertEqual(
      TrafficStatisticsPresentation.activeIntervalSummary(from: intervals),
      "4 个进行中"
    )
    XCTAssertEqual(TrafficStatisticsPresentation.activeIntervalCount(from: intervals), 4)
  }

  func testActiveIntervalSummaryUsesStableEmptyState() {
    let intervals = [
      makeInterval(name: "已完成", status: .completed),
      makeInterval(name: "已中断", status: .interrupted),
    ]

    XCTAssertEqual(
      TrafficStatisticsPresentation.activeIntervalSummary(from: intervals),
      "未开始"
    )
  }

  func testQuickTaskSnapshotKeepsActiveTasksAndFillsWithTodayEndedTasks() {
    let calendar = utcCalendar()
    let now = Date(timeIntervalSince1970: 1_700_800_000)
    let active = makeInterval(
      name: "跨日进行中",
      status: .active,
      startedAt: now.addingTimeInterval(-90_000)
    )
    let recentCompleted = makeInterval(
      name: "最近完成",
      status: .completed,
      startedAt: now.addingTimeInterval(-3_600),
      endedAt: now.addingTimeInterval(-60)
    )
    let earlierInterrupted = makeInterval(
      name: "较早中断",
      status: .interrupted,
      startedAt: now.addingTimeInterval(-7_200),
      endedAt: now.addingTimeInterval(-3_600)
    )
    let yesterdayCompleted = makeInterval(
      name: "昨天完成",
      status: .completed,
      startedAt: now.addingTimeInterval(-100_000),
      endedAt: now.addingTimeInterval(-90_000)
    )

    let snapshot = TrafficStatisticsPresentation.quickTaskSnapshot(
      from: [earlierInterrupted, yesterdayCompleted, recentCompleted, active],
      calendar: calendar,
      now: now
    )

    XCTAssertEqual(snapshot.slots.count, 5)
    XCTAssertEqual(
      snapshot.slots.compactMap { $0?.name },
      ["跨日进行中", "最近完成", "较早中断"]
    )
    XCTAssertEqual(snapshot.additionalCount, 0)
  }

  func testQuickTaskSnapshotUsesFiveStableSlotsAndReportsOverflow() {
    let now = Date(timeIntervalSince1970: 1_700_800_000)
    let intervals = (0..<7).map { index in
      makeInterval(
        name: "任务 \(index)",
        status: .active,
        startedAt: now.addingTimeInterval(TimeInterval(index))
      )
    }

    let snapshot = TrafficStatisticsPresentation.quickTaskSnapshot(
      from: intervals,
      calendar: utcCalendar(),
      now: now
    )

    XCTAssertEqual(snapshot.slots.count, 5)
    XCTAssertEqual(
      snapshot.slots.compactMap { $0?.name },
      ["任务 6", "任务 5", "任务 4", "任务 3", "任务 2"]
    )
    XCTAssertEqual(snapshot.additionalCount, 2)
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
    status: TrafficIntervalStatus,
    startedAt: Date = Date(timeIntervalSince1970: 1_000),
    endedAt: Date? = nil
  ) -> TrafficInterval {
    TrafficInterval(
      id: UUID(),
      name: name,
      note: nil,
      status: status,
      startedAt: startedAt,
      endedAt: status == .active ? nil : (endedAt ?? Date(timeIntervalSince1970: 2_000)),
      endReason: status == .active ? nil : .user,
      proxyUsage: TrafficBytes(upload: 1_000, download: 2_000)
    )
  }

  private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }
}
