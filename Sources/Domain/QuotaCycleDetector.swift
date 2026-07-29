import Foundation

enum QuotaCycleDecision: Equatable, Sendable {
  case continueCycle(UUID)
  case startCycle(reason: QuotaCycleStartReason, isUserConfirmed: Bool)
}

enum QuotaCycleDetector {
  static func decision(
    previous: SubscriptionQuotaSnapshot?,
    current: QuotaObservation
  ) -> QuotaCycleDecision {
    guard let previous else {
      return .startCycle(reason: .initial, isUserConfirmed: true)
    }
    guard current.traffic.usedBytes >= previous.traffic.usedBytes else {
      return .startCycle(reason: .usageReset, isUserConfirmed: false)
    }
    return .continueCycle(previous.cycleID)
  }
}
