import Foundation

enum QuotaTrendWindow: String, CaseIterable, Equatable, Sendable {
  case day
  case week
  case month

  var duration: TimeInterval {
    switch self {
    case .day:
      24 * 60 * 60
    case .week:
      7 * 24 * 60 * 60
    case .month:
      30 * 24 * 60 * 60
    }
  }
}

struct QuotaTrendPoint: Identifiable, Equatable, Sendable {
  let id: UUID
  let date: Date
  let traffic: QuotaTraffic
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
  var day = QuotaTrend.empty(window: .day)
  var week = QuotaTrend.empty(window: .week)
  var month = QuotaTrend.empty(window: .month)

  func trend(for window: QuotaTrendWindow) -> QuotaTrend {
    switch window {
    case .day:
      day
    case .week:
      week
    case .month:
      month
    }
  }
}

struct QuotaTrend: Equatable, Sendable {
  let window: QuotaTrendWindow
  let points: [QuotaTrendPoint]
  let consumedBytes: UInt64?
  let dailyConsumptionBytes: Double?
  let depletionForecast: QuotaDepletionForecast

  var estimatedDepletionAt: Date? {
    guard case .available(let date) = depletionForecast else {
      return nil
    }
    return date
  }

  static func empty(window: QuotaTrendWindow) -> QuotaTrend {
    QuotaTrend(
      window: window,
      points: [],
      consumedBytes: nil,
      dailyConsumptionBytes: nil,
      depletionForecast: .unavailable(.insufficientSamples)
    )
  }
}
