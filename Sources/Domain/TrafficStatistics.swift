import Foundation

enum TrafficIntervalStatus: String, Equatable, Sendable {
  case active
  case completed
  case interrupted
}

enum TrafficIntervalEndReason: String, Equatable, Sendable {
  case user
  case applicationExit = "application_exit"
  case monitoringStopped = "monitoring_stopped"
  case recovery
  case statisticsUnavailable = "statistics_unavailable"
}

struct TrafficInterval: Identifiable, Equatable, Sendable {
  let id: UUID
  let name: String
  let note: String?
  let status: TrafficIntervalStatus
  let startedAt: Date
  let endedAt: Date?
  let endReason: TrafficIntervalEndReason?
  let proxyUsage: TrafficBytes
}

struct TrafficDailyTotal: Equatable, Sendable {
  let localDay: String
  let bytes: TrafficBytes
}

struct TrafficStatisticsSnapshot: Equatable, Sendable {
  let today: CategorizedTrafficBytes
  let lifetime: CategorizedTrafficBytes
  let intervals: [TrafficInterval]
  let recentProxyDays: [TrafficDailyTotal]
  let lastObservedAt: Date?

  static let empty = TrafficStatisticsSnapshot(
    today: .zero,
    lifetime: .zero,
    intervals: [],
    recentProxyDays: [],
    lastObservedAt: nil
  )
}

enum TrafficStatisticsError: Error, Equatable, LocalizedError {
  case invalidIntervalName
  case intervalNotActive
  case database(String)
  case unsupportedSchema(Int)
  case byteCountOverflow

  var errorDescription: String? {
    switch self {
    case .invalidIntervalName:
      "统计任务名称不能为空。"
    case .intervalNotActive:
      "该统计任务已不在进行中。"
    case .database:
      "本地统计数据库暂不可用。"
    case .unsupportedSchema:
      "本地统计数据库版本暂不受支持。"
    case .byteCountOverflow:
      "流量累计值超出本地数据库支持范围。"
    }
  }
}
