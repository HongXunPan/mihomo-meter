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
  static let quickActiveLimit = 3

  static func suggestedIntervalName(from intervals: [TrafficInterval]) -> String {
    "统计任务 \(intervals.count + 1)"
  }

  static func quickActiveIntervals(from intervals: [TrafficInterval]) -> [TrafficInterval] {
    Array(
      intervals
        .lazy
        .filter { $0.status == .active }
        .prefix(quickActiveLimit)
    )
  }

  static func additionalActiveCount(from intervals: [TrafficInterval]) -> Int {
    max(intervals.filter { $0.status == .active }.count - quickActiveLimit, 0)
  }
}
