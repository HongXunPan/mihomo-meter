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

  func reset() async throws {
    do {
      try requirePersistence().reset()
    } catch {
      persistence = nil
      throw error
    }
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
      for event in QuotaEventDetector.events(previous: previous, current: snapshot) {
        try persistence.events.insert(event)
      }
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

  func events(
    for subscriptionID: UUID,
    limit: Int
  ) async throws -> [QuotaEvent] {
    guard limit > 0 else {
      return []
    }
    return try requirePersistence().events.load(for: subscriptionID, limit: limit)
  }

  func confirmCycle(id: UUID) async throws {
    let persistence = try requirePersistence()
    try persistence.transaction {
      try persistence.cycles.confirm(id: id)
      try persistence.events.confirmUsageReset(cycleID: id)
    }
  }

  func analysis(
    for subscriptionID: UUID,
    at date: Date
  ) async throws -> SubscriptionQuotaAnalysis {
    let persistence = try requirePersistence()
    guard let subscription = try persistence.subscriptions.load(id: subscriptionID) else {
      throw QuotaLedgerError.subscriptionNotFound
    }
    let latestQuota = try persistence.snapshots.latest(for: subscriptionID)
    let currentCycle = try persistence.cycles.open(for: subscriptionID)
    let snapshots = try persistence.snapshots.load(
      for: subscriptionID,
      from: QuotaTrendWindow.year.startDate(endingAt: date),
      through: date
    )
    return try SubscriptionQuotaAnalysis(
      latestQuota: latestQuota,
      trends: RuntimeQuotaTrends(
        day: trend(
          for: subscription,
          window: .day,
          now: date,
          latestQuota: latestQuota,
          currentCycle: currentCycle,
          snapshots: snapshots
        ),
        week: trend(
          for: subscription,
          window: .week,
          now: date,
          latestQuota: latestQuota,
          currentCycle: currentCycle,
          snapshots: snapshots
        ),
        month: trend(
          for: subscription,
          window: .month,
          now: date,
          latestQuota: latestQuota,
          currentCycle: currentCycle,
          snapshots: snapshots
        ),
        year: trend(
          for: subscription,
          window: .year,
          now: date,
          latestQuota: latestQuota,
          currentCycle: currentCycle,
          snapshots: snapshots
        )
      ),
      currentCycle: currentCycle,
      recentEvents: persistence.events.load(for: subscriptionID, limit: 5)
    )
  }

  func trend(
    for subscriptionID: UUID,
    window: QuotaTrendWindow,
    now: Date
  ) async throws -> QuotaTrend {
    let persistence = try requirePersistence()
    guard let subscription = try persistence.subscriptions.load(id: subscriptionID) else {
      throw QuotaLedgerError.subscriptionNotFound
    }
    return try trend(
      for: subscription,
      window: window,
      now: now,
      latestQuota: persistence.snapshots.latest(for: subscriptionID),
      currentCycle: persistence.cycles.open(for: subscriptionID),
      snapshots: persistence.snapshots.load(
        for: subscriptionID,
        from: window.startDate(endingAt: now),
        through: now
      )
    )
  }

  func profileQueryState(
    for subscriptionID: UUID
  ) async throws -> ProfileQuotaQueryState? {
    try requirePersistence().queryStates.load(for: subscriptionID)
  }

  func saveProfileQueryState(
    _ state: ProfileQuotaQueryState
  ) async throws {
    let persistence = try requirePersistence()
    try persistence.transaction {
      guard try persistence.subscriptions.load(id: state.subscriptionID) != nil else {
        throw QuotaLedgerError.subscriptionNotFound
      }
      try persistence.queryStates.upsert(state)
    }
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

  private func maximumDataAge(for subscription: TrackedSubscription) -> TimeInterval {
    let minimumAge: TimeInterval = 24 * 60 * 60
    guard let refreshIntervalMinutes = subscription.refreshIntervalMinutes else {
      return minimumAge
    }
    return max(minimumAge, TimeInterval(refreshIntervalMinutes) * 2 * 60)
  }

  private func trend(
    for subscription: TrackedSubscription,
    window: QuotaTrendWindow,
    now: Date,
    latestQuota: SubscriptionQuotaSnapshot?,
    currentCycle: QuotaCycle?,
    snapshots: [SubscriptionQuotaSnapshot]
  ) throws -> QuotaTrend {
    return QuotaTrendEngine.calculate(
      snapshots: snapshots,
      window: window,
      now: now,
      context: QuotaTrendContext(
        latestSnapshot: latestQuota,
        currentCycle: currentCycle,
        maximumDataAge: maximumDataAge(for: subscription)
      )
    )
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
