import Foundation

enum ConnectionAttributionLabel {
  static let unknownApplication = "未知应用"
  static let unknownHostname = "未知域名"
  static let overflow = "其他"
}

struct ConnectionAttributionStorageKey: Hashable, Sendable {
  let localDay: String
  let applicationName: String
  let hostname: String
}

struct ConnectionAttributionAggregate: Equatable, Sendable {
  let key: ConnectionAttributionStorageKey
  let bytes: TrafficBytes
}

struct ConnectionAttributionRecord: Equatable, Sendable {
  let localDay: String
  let applicationName: String
  let hostname: String
  let bytes: TrafficBytes
}

struct ConnectionAnalyticsCoverage: Equatable, Sendable {
  let total: TrafficBytes
  let hostnameAttributed: TrafficBytes
  let applicationAttributed: TrafficBytes
  let fullyAttributed: TrafficBytes

  static let empty = ConnectionAnalyticsCoverage(
    total: .zero,
    hostnameAttributed: .zero,
    applicationAttributed: .zero,
    fullyAttributed: .zero
  )

  var hostnameRate: Double? {
    rate(for: hostnameAttributed)
  }

  var applicationRate: Double? {
    rate(for: applicationAttributed)
  }

  var fullyAttributedRate: Double? {
    rate(for: fullyAttributed)
  }

  private func rate(for bytes: TrafficBytes) -> Double? {
    guard total.total > 0 else {
      return nil
    }
    return min(Double(bytes.total) / Double(total.total), 1)
  }
}

struct ConnectionAnalyticsRecordingCoverage: Equatable, Sendable {
  let attributed: TrafficBytes
  let coreProxy: TrafficBytes

  var rate: Double? {
    guard coreProxy.total > 0 else {
      return nil
    }
    return min(Double(attributed.total) / Double(coreProxy.total), 1)
  }
}

struct ConnectionAnalyticsDay: Equatable, Sendable {
  let localDay: String
  let bytes: TrafficBytes
  let coverage: ConnectionAnalyticsCoverage
}

struct ConnectionAnalyticsLedgerSnapshot: Equatable, Sendable {
  let isHistoryEnabled: Bool
  let recentDays: [ConnectionAnalyticsDay]

  static let empty = ConnectionAnalyticsLedgerSnapshot(
    isHistoryEnabled: false,
    recentDays: []
  )
}

enum ConnectionAnalyticsError: Error, Equatable, LocalizedError {
  case database(String)
  case unsupportedSchema(Int)
  case byteCountOverflow

  var errorDescription: String? {
    switch self {
    case .database:
      "连接归因数据库暂不可用，实时连接不受影响。"
    case .unsupportedSchema:
      "连接归因数据库版本暂不受支持，实时连接不受影响。"
    case .byteCountOverflow:
      "连接归因累计值超出本地数据库支持范围。"
    }
  }
}

enum ConnectionAnalyticsCalendar {
  static func localDay(for date: Date, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(
      format: "%04d-%02d-%02d",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0
    )
  }
}
