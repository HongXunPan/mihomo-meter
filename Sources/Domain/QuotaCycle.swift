import Foundation

enum QuotaCycleStartReason: String, Equatable, Sendable {
  case initial
  case usageReset = "usage_reset"
}

struct QuotaCycle: Identifiable, Equatable, Sendable {
  let id: UUID
  let subscriptionID: UUID
  let startedAt: Date
  let endedAt: Date?
  let startReason: QuotaCycleStartReason
  let isUserConfirmed: Bool

  init(
    id: UUID = UUID(),
    subscriptionID: UUID,
    startedAt: Date,
    endedAt: Date? = nil,
    startReason: QuotaCycleStartReason,
    isUserConfirmed: Bool
  ) {
    self.id = id
    self.subscriptionID = subscriptionID
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.startReason = startReason
    self.isUserConfirmed = isUserConfirmed
  }
}
