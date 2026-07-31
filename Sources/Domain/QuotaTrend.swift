import Foundation

enum QuotaTrendWindow: String, CaseIterable, Equatable, Sendable {
  case day
  case week
  case month
  case year

  var duration: TimeInterval {
    switch self {
    case .day:
      24 * 60 * 60
    case .week:
      7 * 24 * 60 * 60
    case .month:
      30 * 24 * 60 * 60
    case .year:
      365 * 24 * 60 * 60
    }
  }

  func startDate(endingAt date: Date, calendar: Calendar = .current) -> Date {
    if self == .year,
      let yearStart = calendar.date(byAdding: .month, value: -12, to: date)
    {
      return yearStart
    }
    return date.addingTimeInterval(-duration)
  }

  var defaultUsageAggregation: QuotaUsageAggregation {
    switch self {
    case .day:
      .hour
    case .week, .month:
      .day
    case .year:
      .month
    }
  }
}

struct QuotaTrendPoint: Identifiable, Equatable, Sendable {
  let id: UUID
  let date: Date
  let traffic: QuotaTraffic
}

struct QuotaTrendSegment: Identifiable, Equatable, Sendable {
  let cycleID: UUID
  let points: [QuotaTrendPoint]

  var id: UUID {
    cycleID
  }
}

enum QuotaForecastUnavailableReason: Equatable, Sendable {
  case insufficientSamples
  case insufficientObservationSpan
  case staleData
  case unconfirmedCycle
  case noRecentConsumption
  case expired
  case depleted
}

enum QuotaDepletionForecast: Equatable, Sendable {
  case available(Date)
  case unavailable(QuotaForecastUnavailableReason)
}

struct QuotaTrendContext: Equatable, Sendable {
  let latestSnapshot: SubscriptionQuotaSnapshot?
  let currentCycle: QuotaCycle?
  let maximumDataAge: TimeInterval
}

struct RuntimeQuotaTrends: Equatable, Sendable {
  static let depletionForecastWindow = QuotaTrendWindow.week

  var day = QuotaTrend.empty(window: .day)
  var week = QuotaTrend.empty(window: .week)
  var month = QuotaTrend.empty(window: .month)
  var year = QuotaTrend.empty(window: .year)

  var depletionForecast: QuotaDepletionForecast {
    trend(for: Self.depletionForecastWindow).depletionForecast
  }

  func trend(for window: QuotaTrendWindow) -> QuotaTrend {
    switch window {
    case .day:
      day
    case .week:
      week
    case .month:
      month
    case .year:
      year
    }
  }
}

struct QuotaTrend: Equatable, Sendable {
  let window: QuotaTrendWindow
  let points: [QuotaTrendPoint]
  let segments: [QuotaTrendSegment]
  let usageByAggregation: [QuotaUsageAggregation: QuotaUsageSeries]
  let consumedBytes: UInt64?
  let dailyConsumptionBytes: Double?
  let depletionForecast: QuotaDepletionForecast

  var estimatedDepletionAt: Date? {
    guard case .available(let date) = depletionForecast else {
      return nil
    }
    return date
  }

  func usageSeries(for aggregation: QuotaUsageAggregation) -> QuotaUsageSeries {
    usageByAggregation[aggregation] ?? .empty(aggregation: aggregation)
  }

  static func empty(window: QuotaTrendWindow) -> QuotaTrend {
    QuotaTrend(
      window: window,
      points: [],
      segments: [],
      usageByAggregation: [:],
      consumedBytes: nil,
      dailyConsumptionBytes: nil,
      depletionForecast: .unavailable(.insufficientSamples)
    )
  }
}
