import Foundation

struct SubscriptionQuotaSnapshot: Identifiable, Equatable, Sendable {
  let id: UUID
  let cycleID: UUID
  let observation: QuotaObservation

  var subscriptionID: UUID {
    observation.subscriptionID
  }

  var observedAt: Date {
    observation.observedAt
  }

  var effectiveAt: Date {
    observation.effectiveAt
  }

  var source: QuotaObservationSource {
    observation.source
  }

  var traffic: QuotaTraffic {
    observation.traffic
  }

  var expireAt: Date? {
    observation.expireAt
  }
}
