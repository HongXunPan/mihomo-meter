import Foundation

struct RuntimeQuotaCandidate: Equatable, Sendable {
  let sourceKey: String
  let sourceUpdatedAt: Date?
  let traffic: QuotaTraffic
  let expireAt: Date?

  func matches(_ snapshot: SubscriptionQuotaSnapshot) -> Bool {
    let hasSameQuota =
      traffic == snapshot.traffic
      && expireAt == snapshot.expireAt
    guard hasSameQuota else {
      return false
    }
    guard let sourceUpdatedAt else {
      return true
    }
    return sourceUpdatedAt == snapshot.observation.sourceUpdatedAt
  }
}

enum RuntimeQuotaCandidateSelection: Equatable, Sendable {
  case none
  case single(RuntimeQuotaCandidate)
  case multiple(count: Int)

  init(candidates: [RuntimeQuotaCandidate]) {
    switch candidates.count {
    case 0:
      self = .none
    case 1:
      self = .single(candidates[0])
    default:
      self = .multiple(count: candidates.count)
    }
  }
}
