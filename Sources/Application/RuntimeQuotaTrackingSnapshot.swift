import Foundation

enum RuntimeQuotaObservationStatus: Equatable, Sendable {
  case loading
  case controllerUnavailable
  case checking
  case available
  case noCandidate
  case multipleCandidates(Int)
  case failed(String)
  case unavailable(String)
}

enum RuntimeQuotaPauseReason: Equatable, Sendable {
  case previousAmbiguity
  case noCandidate
  case multipleCandidates
  case sourceChanged
  case controllerChanged
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

struct RuntimeQuotaTrackingSnapshot: Equatable, Sendable {
  var subscription: TrackedSubscription?
  var latestQuota: SubscriptionQuotaSnapshot?
  var trends = RuntimeQuotaTrends()
  var observationStatus = RuntimeQuotaObservationStatus.loading
  var pauseReason: RuntimeQuotaPauseReason?

  static let empty = RuntimeQuotaTrackingSnapshot()

  var isActive: Bool {
    subscription?.status == .active
  }

  var isPaused: Bool {
    subscription?.status == .paused
  }
}
