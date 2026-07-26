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

struct QuotaTrend: Equatable, Sendable {
  let window: QuotaTrendWindow
  let points: [QuotaTrendPoint]
  let consumedBytes: UInt64?
  let dailyConsumptionBytes: Double?
  let estimatedDepletionAt: Date?

  static func empty(window: QuotaTrendWindow) -> QuotaTrend {
    QuotaTrend(
      window: window,
      points: [],
      consumedBytes: nil,
      dailyConsumptionBytes: nil,
      estimatedDepletionAt: nil
    )
  }
}
