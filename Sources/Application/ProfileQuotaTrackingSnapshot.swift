import Foundation

enum ProfileQuotaQueryStatus: Equatable, Sendable {
  case unavailableProfile
  case waitingForProxy
  case scheduled(Date)
  case querying
  case available
  case failed(
    message: String,
    retryAt: Date?,
    manualRetryPolicy: ProfileQuotaManualRetryPolicy
  )
  case storageUnavailable(String)

  var allowsImmediateManualRetry: Bool {
    guard case .failed(_, _, .immediate) = self else {
      return false
    }
    return true
  }
}

enum ProfileQuotaManualRetryPolicy: Equatable, Sendable {
  case cooldown
  case immediate
}

struct ProfileQuotaTrackingItem: Identifiable, Equatable, Sendable {
  let subscription: TrackedSubscription
  let profileUID: String
  let isCurrent: Bool
  let availability: ClashProfileAvailability
  let analysis: SubscriptionQuotaAnalysis
  let queryStatus: ProfileQuotaQueryStatus
  let isManualRefreshEligible: Bool
  let manualRefreshAvailableAt: Date?

  var id: UUID {
    subscription.id
  }

  var latestQuota: SubscriptionQuotaSnapshot? {
    analysis.latestQuota
  }

  var trends: RuntimeQuotaTrends {
    analysis.trends
  }

  func canRefresh(at date: Date) -> Bool {
    guard isManualRefreshEligible else {
      return false
    }
    if queryStatus.allowsImmediateManualRetry {
      return true
    }
    return manualRefreshAvailableAt.map { $0 <= date } ?? true
  }
}

struct ProfileQuotaTrackingSnapshot: Equatable, Sendable {
  var profiles: [ProfileQuotaTrackingItem] = []
  var isRefreshingAll = false
  var storageErrorMessage: String?

  static let empty = ProfileQuotaTrackingSnapshot()
}
