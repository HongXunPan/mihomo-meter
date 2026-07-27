import Foundation

struct ActiveQuotaQueryResult: Equatable, Sendable {
  let traffic: QuotaTraffic
  let expireAt: Date?
}
