import Foundation

actor SQLiteQuotaLedger: QuotaLedgerStoring {
  private let databaseURL: URL
  private var persistence: QuotaLedgerPersistence?

  init(databaseURL: URL) {
    self.databaseURL = databaseURL
  }

  func prepare() async throws {
    _ = try requirePersistence()
  }

  func upsertSubscription(
    _ subscription: TrackedSubscription
  ) async throws -> TrackedSubscription {
    let persistence = try requirePersistence()
    return try persistence.transaction {
      if let existing = try persistence.subscriptions.load(id: subscription.id) {
        guard existing.identity == subscription.identity else {
          throw QuotaLedgerError.identityChangeRequiresMigration
        }
      }
      try persistence.subscriptions.upsert(subscription)
      guard let stored = try persistence.subscriptions.load(id: subscription.id) else {
        throw QuotaLedgerError.invalidStoredData
      }
      return stored
    }
  }

  func subscriptions() async throws -> [TrackedSubscription] {
    try requirePersistence().subscriptions.loadAll()
  }

  func record(
    _ observation: QuotaObservation
  ) async throws -> SubscriptionQuotaSnapshot {
    let persistence = try requirePersistence()
    return try persistence.transaction {
      guard let subscription = try persistence.subscriptions.load(id: observation.subscriptionID)
      else {
        throw QuotaLedgerError.subscriptionNotFound
      }
      try validateSource(observation.source, identity: subscription.identity)

      let previous = try persistence.snapshots.latest(for: observation.subscriptionID)
      if let previous, observation.observedAt <= previous.observedAt {
        throw QuotaLedgerError.nonMonotonicObservation
      }
      let cycleID = try resolveCycleID(
        previous: previous,
        observation: observation,
        persistence: persistence
      )
      let snapshot = SubscriptionQuotaSnapshot(
        id: UUID(),
        cycleID: cycleID,
        observation: observation
      )
      try persistence.snapshots.insert(snapshot)
      return snapshot
    }
  }

  func latestSnapshot(
    for subscriptionID: UUID
  ) async throws -> SubscriptionQuotaSnapshot? {
    try requirePersistence().snapshots.latest(for: subscriptionID)
  }

  func snapshots(
    for subscriptionID: UUID,
    from startDate: Date,
    through endDate: Date
  ) async throws -> [SubscriptionQuotaSnapshot] {
    guard startDate <= endDate else {
      throw QuotaLedgerError.invalidTimeRange
    }
    return try requirePersistence().snapshots.load(
      for: subscriptionID,
      from: startDate,
      through: endDate
    )
  }

  func cycles(for subscriptionID: UUID) async throws -> [QuotaCycle] {
    try requirePersistence().cycles.load(for: subscriptionID)
  }

  func trend(
    for subscriptionID: UUID,
    window: QuotaTrendWindow,
    now: Date
  ) async throws -> QuotaTrend {
    let snapshots = try await snapshots(
      for: subscriptionID,
      from: now.addingTimeInterval(-window.duration),
      through: now
    )
    return QuotaTrendEngine.calculate(snapshots: snapshots, window: window, now: now)
  }

  private func requirePersistence() throws -> QuotaLedgerPersistence {
    if let persistence {
      return persistence
    }
    let persistence = try QuotaLedgerPersistence(databaseURL: databaseURL)
    self.persistence = persistence
    return persistence
  }

  private func validateSource(
    _ source: QuotaObservationSource,
    identity: SubscriptionIdentity
  ) throws {
    switch (identity, source) {
    case (.runtimeSingle, .mihomoRuntime), (.clashProfile, .meterActiveQuery):
      return
    default:
      throw QuotaLedgerError.sourceMismatch
    }
  }

  private func resolveCycleID(
    previous: SubscriptionQuotaSnapshot?,
    observation: QuotaObservation,
    persistence: QuotaLedgerPersistence
  ) throws -> UUID {
    switch QuotaCycleDetector.decision(previous: previous, current: observation) {
    case .continueCycle(let cycleID):
      return cycleID
    case .startCycle(let reason, let isUserConfirmed):
      if let previous {
        try persistence.cycles.close(id: previous.cycleID, at: observation.observedAt)
      }
      let cycle = QuotaCycle(
        subscriptionID: observation.subscriptionID,
        startedAt: observation.observedAt,
        startReason: reason,
        isUserConfirmed: isUserConfirmed
      )
      try persistence.cycles.insert(cycle)
      return cycle.id
    }
  }
}
