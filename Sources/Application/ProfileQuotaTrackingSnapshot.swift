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
  let latestQuota: SubscriptionQuotaSnapshot?
  let trends: RuntimeQuotaTrends
  let queryStatus: ProfileQuotaQueryStatus
  let canRefresh: Bool
  let manualRefreshAvailableAt: Date?

  var id: UUID {
    subscription.id
  }
}

struct ProfileQuotaTrackingSnapshot: Equatable, Sendable {
  var profiles: [ProfileQuotaTrackingItem] = []
  var isRefreshingAll = false
  var storageErrorMessage: String?

  static let empty = ProfileQuotaTrackingSnapshot()
}
