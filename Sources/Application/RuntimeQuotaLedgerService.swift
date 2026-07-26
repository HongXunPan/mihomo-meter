import Foundation

struct RuntimeQuotaStoredState: Equatable, Sendable {
  var subscription: TrackedSubscription?
  var latestQuota: SubscriptionQuotaSnapshot?
  var trends = RuntimeQuotaTrends()
}

struct RuntimeQuotaLedgerService: Sendable {
  private let ledger: any QuotaLedgerStoring

  init(ledger: any QuotaLedgerStoring) {
    self.ledger = ledger
  }

  func prepare(at date: Date) async throws -> RuntimeQuotaStoredState {
    try await ledger.prepare()
    let subscriptions = try await ledger.subscriptions().filter {
      $0.identity == .runtimeSingle
        && ($0.status == .active || $0.status == .paused)
    }
    guard subscriptions.count <= 1 else {
      throw RuntimeQuotaTrackingError.multipleRuntimeSubscriptions
    }
    guard let subscription = subscriptions.first else {
      return RuntimeQuotaStoredState()
    }
    let latestQuota = try await ledger.latestSnapshot(for: subscription.id)
    return RuntimeQuotaStoredState(
      subscription: subscription,
      latestQuota: latestQuota,
      trends: try await loadTrends(for: subscription.id, referenceDate: date)
    )
  }

  func enable(
    candidate: RuntimeQuotaCandidate,
    at date: Date
  ) async throws -> RuntimeQuotaStoredState {
    let subscription = try TrackedSubscription(
      id: UUID(),
      name: "当前运行订阅",
      identity: .runtimeSingle,
      createdAt: date,
      updatedAt: date
    )
    let stored = try await ledger.upsertSubscription(subscription)
    return try await record(
      candidate: candidate,
      state: RuntimeQuotaStoredState(subscription: stored),
      at: date
    )
  }

  func resume(
    candidate: RuntimeQuotaCandidate,
    state: RuntimeQuotaStoredState,
    at date: Date
  ) async throws -> RuntimeQuotaStoredState {
    guard let subscription = state.subscription else {
      return state
    }
    var resumedState = state
    resumedState.subscription = try await ledger.upsertSubscription(
      updating(subscription, status: .active, at: date)
    )
    return try await record(candidate: candidate, state: resumedState, at: date)
  }

  func pause(
    state: RuntimeQuotaStoredState,
    at date: Date
  ) async throws -> RuntimeQuotaStoredState {
    guard let subscription = state.subscription, subscription.status == .active else {
      return state
    }
    var pausedState = state
    pausedState.subscription = try await ledger.upsertSubscription(
      updating(subscription, status: .paused, at: date)
    )
    return pausedState
  }

  func record(
    candidate: RuntimeQuotaCandidate,
    state: RuntimeQuotaStoredState,
    at date: Date
  ) async throws -> RuntimeQuotaStoredState {
    guard let subscription = state.subscription else {
      return state
    }
    if let latestQuota = state.latestQuota, candidate.matches(latestQuota) {
      return state
    }

    let observation = QuotaObservation(
      subscriptionID: subscription.id,
      observedAt: date,
      sourceUpdatedAt: candidate.sourceUpdatedAt,
      source: .mihomoRuntime,
      traffic: candidate.traffic,
      expireAt: candidate.expireAt
    )
    return RuntimeQuotaStoredState(
      subscription: subscription,
      latestQuota: try await ledger.record(observation),
      trends: try await loadTrends(for: subscription.id, referenceDate: date)
    )
  }

  private func updating(
    _ subscription: TrackedSubscription,
    status: SubscriptionTrackingStatus,
    at date: Date
  ) throws -> TrackedSubscription {
    try TrackedSubscription(
      id: subscription.id,
      name: subscription.name,
      identity: subscription.identity,
      urlFingerprint: subscription.urlFingerprint,
      refreshIntervalMinutes: subscription.refreshIntervalMinutes,
      status: status,
      createdAt: subscription.createdAt,
      updatedAt: date
    )
  }

  private func loadTrends(
    for subscriptionID: UUID,
    referenceDate: Date
  ) async throws -> RuntimeQuotaTrends {
    let day = try await ledger.trend(for: subscriptionID, window: .day, now: referenceDate)
    let week = try await ledger.trend(for: subscriptionID, window: .week, now: referenceDate)
    let month = try await ledger.trend(for: subscriptionID, window: .month, now: referenceDate)
    return RuntimeQuotaTrends(day: day, week: week, month: month)
  }
}

enum RuntimeQuotaTrackingError: Error, LocalizedError {
  case multipleRuntimeSubscriptions

  var errorDescription: String? {
    "检测到多个轻量订阅记录，已停止自动归属。"
  }
}
