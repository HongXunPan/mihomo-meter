import Foundation

struct ProfileQuotaLedgerService {
  private let ledger: any QuotaLedgerStoring

  init(ledger: any QuotaLedgerStoring) {
    self.ledger = ledger
  }

  func prepare() async throws {
    try await ledger.prepare()
  }

  func queryState(for subscriptionID: UUID) async throws -> ProfileQuotaQueryState? {
    try await ledger.profileQueryState(for: subscriptionID)
  }

  func saveQueryState(_ state: ProfileQuotaQueryState) async throws {
    try await ledger.saveProfileQueryState(state)
  }

  func record(
    result: ActiveQuotaQueryResult,
    for subscription: TrackedSubscription,
    at date: Date
  ) async throws {
    let latest = try await ledger.latestSnapshot(for: subscription.id)
    let observedAt = max(date, latest?.observedAt.addingTimeInterval(0.001) ?? date)
    _ = try await ledger.record(
      QuotaObservation(
        subscriptionID: subscription.id,
        observedAt: observedAt,
        sourceUpdatedAt: nil,
        source: .meterActiveQuery,
        traffic: result.traffic,
        expireAt: result.expireAt
      )
    )
  }

  func quotaState(
    for subscriptionID: UUID,
    at date: Date
  ) async throws -> (SubscriptionQuotaSnapshot?, RuntimeQuotaTrends) {
    async let latest = ledger.latestSnapshot(for: subscriptionID)
    async let day = ledger.trend(for: subscriptionID, window: .day, now: date)
    async let week = ledger.trend(for: subscriptionID, window: .week, now: date)
    async let month = ledger.trend(for: subscriptionID, window: .month, now: date)
    return try await (
      latest,
      RuntimeQuotaTrends(day: day, week: week, month: month)
    )
  }
}
