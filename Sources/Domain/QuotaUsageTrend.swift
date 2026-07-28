import Foundation

enum QuotaUsageAggregation: String, Equatable, Hashable, Sendable {
  case automatic
  case hour
  case threeHour
  case sixHour
  case twelveHour
  case day
  case week
  case month

  static let selectableCases: [QuotaUsageAggregation] = [
    .automatic,
    .hour,
    .day,
    .week,
    .month,
  ]

  static let calculationCases: [QuotaUsageAggregation] = [
    .hour,
    .threeHour,
    .sixHour,
    .twelveHour,
    .day,
    .week,
    .month,
  ]

  var nominalDuration: TimeInterval {
    switch self {
    case .automatic:
      0
    case .hour:
      3_600
    case .threeHour:
      3 * 3_600
    case .sixHour:
      6 * 3_600
    case .twelveHour:
      12 * 3_600
    case .day:
      24 * 3_600
    case .week:
      7 * 24 * 3_600
    case .month:
      31 * 24 * 3_600
    }
  }
}

struct QuotaUsagePeriodID: Hashable, Sendable {
  let startAt: Date
  let endAt: Date
}

struct QuotaUsageInterval: Identifiable, Equatable, Sendable {
  let id: UUID
  let cycleID: UUID
  let startAt: Date
  let endAt: Date
  let uploadBytes: UInt64
  let downloadBytes: UInt64

  var duration: TimeInterval {
    endAt.timeIntervalSince(startAt)
  }

  var totalBytes: UInt64 {
    uploadBytes + downloadBytes
  }
}

struct QuotaUsageBar: Identifiable, Equatable, Sendable {
  let id: QuotaUsagePeriodID
  let startAt: Date
  let endAt: Date
  let uploadBytes: UInt64
  let downloadBytes: UInt64
  let intervalCount: Int
  let isBoundaryApproximation: Bool

  var totalBytes: UInt64 {
    uploadBytes + downloadBytes
  }
}

struct QuotaUsageSeries: Equatable, Sendable {
  let requestedAggregation: QuotaUsageAggregation
  let resolvedAggregation: QuotaUsageAggregation
  let bars: [QuotaUsageBar]
  let unresolvedIntervals: [QuotaUsageInterval]
  let rangeStart: Date
  let rangeEnd: Date

  var isAvailable: Bool {
    switch requestedAggregation {
    case .automatic:
      !bars.isEmpty || !unresolvedIntervals.isEmpty
    case .hour, .threeHour, .sixHour, .twelveHour, .day, .week, .month:
      bars.count >= 2
    }
  }

  var totalUploadBytes: UInt64 {
    bars.reduce(0) { $0 + $1.uploadBytes }
  }

  var totalDownloadBytes: UInt64 {
    bars.reduce(0) { $0 + $1.downloadBytes }
  }

  var coverageStart: Date? {
    let barStart = bars.map(\.startAt).min()
    let unresolvedStart = unresolvedIntervals.map(\.startAt).min()
    return [barStart, unresolvedStart].compactMap { $0 }.min()
  }

  var coverageEnd: Date? {
    let barEnd = bars.map(\.endAt).max()
    let unresolvedEnd = unresolvedIntervals.map(\.endAt).max()
    return [barEnd, unresolvedEnd].compactMap { $0 }.max()
  }

  var coverageDuration: TimeInterval? {
    guard let coverageStart, let coverageEnd else {
      return nil
    }
    return max(coverageEnd.timeIntervalSince(coverageStart), 0)
  }

  static func empty(
    aggregation: QuotaUsageAggregation,
    rangeStart: Date = .distantPast,
    rangeEnd: Date = .distantPast
  ) -> QuotaUsageSeries {
    QuotaUsageSeries(
      requestedAggregation: aggregation,
      resolvedAggregation: aggregation,
      bars: [],
      unresolvedIntervals: [],
      rangeStart: rangeStart,
      rangeEnd: rangeEnd
    )
  }
}
