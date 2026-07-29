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

struct RuntimeQuotaTrackingSnapshot: Equatable, Sendable {
  var subscription: TrackedSubscription?
  var analysis = SubscriptionQuotaAnalysis.empty
  var observationStatus = RuntimeQuotaObservationStatus.loading
  var pauseReason: RuntimeQuotaPauseReason?

  static let empty = RuntimeQuotaTrackingSnapshot()

  var isActive: Bool {
    subscription?.status == .active
  }

  var isPaused: Bool {
    subscription?.status == .paused
  }

  var latestQuota: SubscriptionQuotaSnapshot? {
    analysis.latestQuota
  }

  var trends: RuntimeQuotaTrends {
    analysis.trends
  }
}
