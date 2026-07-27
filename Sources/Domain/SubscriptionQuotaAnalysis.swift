import Foundation

struct SubscriptionQuotaAnalysis: Equatable, Sendable {
  var latestQuota: SubscriptionQuotaSnapshot?
  var trends: RuntimeQuotaTrends
  var currentCycle: QuotaCycle?
  var recentEvents: [QuotaEvent]

  static let empty = SubscriptionQuotaAnalysis(
    latestQuota: nil,
    trends: RuntimeQuotaTrends(),
    currentCycle: nil,
    recentEvents: []
  )

  var pendingCycleConfirmation: QuotaCycle? {
    guard let currentCycle, !currentCycle.isUserConfirmed else {
      return nil
    }
    return currentCycle
  }
}
