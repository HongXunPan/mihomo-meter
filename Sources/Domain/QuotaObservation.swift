import Foundation

enum QuotaObservationSource: String, Equatable, Sendable {
  case mihomoRuntime = "mihomo_runtime"
  case meterActiveQuery = "meter_active_query"
}

struct QuotaObservation: Equatable, Sendable {
  let subscriptionID: UUID
  let observedAt: Date
  let sourceUpdatedAt: Date?
  let source: QuotaObservationSource
  let traffic: QuotaTraffic
  let expireAt: Date?

  var effectiveAt: Date {
    sourceUpdatedAt ?? observedAt
  }
}
