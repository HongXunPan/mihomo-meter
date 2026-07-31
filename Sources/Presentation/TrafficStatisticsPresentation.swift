import Foundation

enum TrafficStatisticsFilter: String, CaseIterable, Identifiable {
  case active
  case history
  case all

  var id: Self {
    self
  }

  var title: String {
    switch self {
    case .active:
      "进行中"
    case .history:
      "历史记录"
    case .all:
      "全部"
    }
  }

  func intervals(from intervals: [TrafficInterval]) -> [TrafficInterval] {
    switch self {
    case .active:
      intervals.filter { $0.status == .active }
    case .history:
      intervals.filter { $0.status != .active }
    case .all:
      intervals
    }
  }
}

enum TrafficStatisticsPresentation {
  static let quickTaskSlotCount = 5

  static func suggestedIntervalName(from intervals: [TrafficInterval]) -> String {
    "统计任务 \(intervals.count + 1)"
  }

  static func activeIntervalSummary(from intervals: [TrafficInterval]) -> String {
    let activeCount = activeIntervalCount(from: intervals)
    return activeCount == 0 ? "未开始" : "\(activeCount) 个进行中"
  }

  static func activeIntervalCount(from intervals: [TrafficInterval]) -> Int {
    intervals.count { $0.status == .active }
  }

  static func quickTaskSnapshot(
    from intervals: [TrafficInterval],
    calendar: Calendar = .autoupdatingCurrent,
    now: Date = Date()
  ) -> TrafficStatisticsQuickTaskSnapshot {
    let activeIntervals =
      intervals
      .filter { $0.status == .active }
      .sorted { $0.startedAt > $1.startedAt }
    let todayEndedIntervals =
      intervals
      .filter { interval in
        guard interval.status != .active, let endedAt = interval.endedAt else {
          return false
        }
        return calendar.isDate(endedAt, inSameDayAs: now)
      }
      .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
    let candidates = activeIntervals + todayEndedIntervals
    let selectedIntervals = Array(candidates.prefix(quickTaskSlotCount))
    let slots =
      selectedIntervals.map(Optional.some)
      + Array(
        repeating: nil,
        count: quickTaskSlotCount - selectedIntervals.count
      )
    return TrafficStatisticsQuickTaskSnapshot(
      slots: slots,
      additionalCount: max(candidates.count - quickTaskSlotCount, 0)
    )
  }
}

struct TrafficStatisticsQuickTaskSnapshot: Equatable {
  let slots: [TrafficInterval?]
  let additionalCount: Int
}
