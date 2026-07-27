import Foundation

protocol QuotaLedgerStoring: Sendable {
  func prepare() async throws

  func upsertSubscription(
    _ subscription: TrackedSubscription
  ) async throws -> TrackedSubscription

  func subscriptions() async throws -> [TrackedSubscription]

  func record(
    _ observation: QuotaObservation
  ) async throws -> SubscriptionQuotaSnapshot

  func latestSnapshot(
    for subscriptionID: UUID
  ) async throws -> SubscriptionQuotaSnapshot?

  func snapshots(
    for subscriptionID: UUID,
    from startDate: Date,
    through endDate: Date
  ) async throws -> [SubscriptionQuotaSnapshot]

  func cycles(for subscriptionID: UUID) async throws -> [QuotaCycle]

  func trend(
    for subscriptionID: UUID,
    window: QuotaTrendWindow,
    now: Date
  ) async throws -> QuotaTrend

  func profileQueryState(
    for subscriptionID: UUID
  ) async throws -> ProfileQuotaQueryState?

  func saveProfileQueryState(
    _ state: ProfileQuotaQueryState
  ) async throws
}
