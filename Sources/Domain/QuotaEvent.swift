import Foundation

enum QuotaEventKind: String, Equatable, Hashable, Sendable {
  case usageReset = "usage_reset"
  case totalIncreased = "total_increased"
  case totalDecreased = "total_decreased"
  case expirationChanged = "expiration_changed"

  var requiresUserConfirmation: Bool {
    self == .usageReset
  }
}

struct QuotaEvent: Identifiable, Equatable, Sendable {
  let id: UUID
  let subscriptionID: UUID
  let previousSnapshotID: UUID
  let currentSnapshotID: UUID
  let occurredAt: Date
  let kind: QuotaEventKind
  let isUserConfirmed: Bool

  init(
    id: UUID = UUID(),
    subscriptionID: UUID,
    previousSnapshotID: UUID,
    currentSnapshotID: UUID,
    occurredAt: Date,
    kind: QuotaEventKind,
    isUserConfirmed: Bool
  ) {
    self.id = id
    self.subscriptionID = subscriptionID
    self.previousSnapshotID = previousSnapshotID
    self.currentSnapshotID = currentSnapshotID
    self.occurredAt = occurredAt
    self.kind = kind
    self.isUserConfirmed = isUserConfirmed
  }
}

enum QuotaEventDetector {
  static func events(
    previous: SubscriptionQuotaSnapshot?,
    current: SubscriptionQuotaSnapshot
  ) -> [QuotaEvent] {
    guard let previous else {
      return []
    }

    var kinds: [QuotaEventKind] = []
    if current.traffic.usedBytes < previous.traffic.usedBytes {
      kinds.append(.usageReset)
    }
    if current.traffic.totalBytes > previous.traffic.totalBytes {
      kinds.append(.totalIncreased)
    } else if current.traffic.totalBytes < previous.traffic.totalBytes {
      kinds.append(.totalDecreased)
    }
    if current.expireAt != previous.expireAt {
      kinds.append(.expirationChanged)
    }

    return kinds.map { kind in
      QuotaEvent(
        subscriptionID: current.subscriptionID,
        previousSnapshotID: previous.id,
        currentSnapshotID: current.id,
        occurredAt: current.effectiveAt,
        kind: kind,
        isUserConfirmed: !kind.requiresUserConfirmation
      )
    }
  }
}
