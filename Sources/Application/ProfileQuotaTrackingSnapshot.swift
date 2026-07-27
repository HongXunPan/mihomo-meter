import Foundation

enum ProfileQuotaQueryStatus: Equatable, Sendable {
  case unavailableProfile
  case waitingForProxy
  case scheduled(Date)
  case querying
  case available
  case failed(message: String, retryAt: Date?)
  case storageUnavailable(String)
}

struct ProfileQuotaTrackingItem: Identifiable, Equatable, Sendable {
  let subscription: TrackedSubscription
  let profileUID: String
  let isCurrent: Bool
  let availability: ClashProfileAvailability
  let analysis: SubscriptionQuotaAnalysis
  let queryStatus: ProfileQuotaQueryStatus
  let canRefresh: Bool
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
}

struct ProfileQuotaTrackingSnapshot: Equatable, Sendable {
  var profiles: [ProfileQuotaTrackingItem] = []
  var isRefreshingAll = false
  var storageErrorMessage: String?

  static let empty = ProfileQuotaTrackingSnapshot()
}
