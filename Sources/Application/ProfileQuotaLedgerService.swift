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

  func analysis(
    for subscriptionID: UUID,
    at date: Date
  ) async throws -> SubscriptionQuotaAnalysis {
    try await ledger.analysis(for: subscriptionID, at: date)
  }

  func confirmCycle(id: UUID) async throws {
    try await ledger.confirmCycle(id: id)
  }
}
