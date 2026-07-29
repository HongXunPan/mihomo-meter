import Foundation

struct ClashProfileTrackingService: Sendable {
  static let supportedIntervals = [60, 180, 360, 720, 1_440]
  static let defaultInterval = 360

  private let ledger: any QuotaLedgerStoring
  private let fingerprinter: any ProfileURLFingerprinting

  init(
    ledger: any QuotaLedgerStoring,
    fingerprinter: any ProfileURLFingerprinting
  ) {
    self.ledger = ledger
    self.fingerprinter = fingerprinter
  }

  func prepare() async throws -> [TrackedSubscription] {
    try await ledger.prepare()
    let subscriptions = try await profileSubscriptions()
    try validateUniqueUIDs(subscriptions)
    return subscriptions
  }

  func reconcile(
    catalog: ClashProfileCatalog,
    at date: Date
  ) async throws -> [TrackedSubscription] {
    let subscriptions = try await profileSubscriptions()
    try validateUniqueUIDs(subscriptions)
    let profilesByUID = Dictionary(uniqueKeysWithValues: catalog.profiles.map { ($0.uid, $0) })

    for subscription in subscriptions {
      guard case .clashProfile(let uid) = subscription.identity else {
        continue
      }
      let updated = try await reconciled(
        subscription,
        with: profilesByUID[uid],
        at: date
      )
      if updated != subscription {
        _ = try await ledger.upsertSubscription(updated)
      }
    }
    return try await profileSubscriptions()
  }

  func setTracking(
    profile: ClashProfile,
    at date: Date
  ) async throws -> [TrackedSubscription] {
    guard profile.supportsActiveQuery else {
      throw ClashProfileTrackingError.unsupportedSubscriptionURL
    }
    let subscriptions = try await profileSubscriptions()
    try validateUniqueUIDs(subscriptions)
    let existing = subscriptions.first { $0.identity == .clashProfile(uid: profile.uid) }

    let fingerprint = try await fingerprinter.fingerprint(for: profile.subscriptionURL)
    let subscription = try TrackedSubscription(
      id: existing?.id ?? UUID(),
      name: profile.name,
      identity: .clashProfile(uid: profile.uid),
      urlFingerprint: fingerprint,
      refreshIntervalMinutes: existing?.refreshIntervalMinutes ?? Self.defaultInterval,
      status: .active,
      createdAt: existing?.createdAt ?? date,
      updatedAt: date
    )
    _ = try await ledger.upsertSubscription(subscription)
    return try await profileSubscriptions()
  }

  func removeTracking(
    profileUID: String,
    at date: Date
  ) async throws -> [TrackedSubscription] {
    let subscriptions = try await profileSubscriptions()
    try validateUniqueUIDs(subscriptions)
    if let existing = subscriptions.first(where: {
      $0.identity == .clashProfile(uid: profileUID) && $0.status != .archived
    }) {
      _ = try await ledger.upsertSubscription(
        try updating(existing, status: .archived, at: date)
      )
    }
    return try await profileSubscriptions()
  }

  func setRefreshInterval(
    _ intervalMinutes: Int,
    profileUID: String,
    at date: Date
  ) async throws -> [TrackedSubscription] {
    guard Self.supportedIntervals.contains(intervalMinutes) else {
      throw ClashProfileTrackingError.unsupportedRefreshInterval
    }
    let subscriptions = try await profileSubscriptions()
    try validateUniqueUIDs(subscriptions)
    guard
      let subscription = subscriptions.first(where: {
        $0.identity == .clashProfile(uid: profileUID) && $0.status != .archived
      })
    else {
      throw ClashProfileTrackingError.subscriptionNotFound
    }
    _ = try await ledger.upsertSubscription(
      try updating(subscription, refreshIntervalMinutes: intervalMinutes, at: date)
    )
    return try await profileSubscriptions()
  }

  private func reconciled(
    _ subscription: TrackedSubscription,
    with profile: ClashProfile?,
    at date: Date
  ) async throws -> TrackedSubscription {
    guard let profile else {
      guard subscription.status == .active || subscription.status == .paused else {
        return subscription
      }
      return try updating(subscription, status: .unsupported, at: date)
    }
    guard subscription.status != .archived else {
      guard subscription.name != profile.name else {
        return subscription
      }
      return try updating(subscription, name: profile.name, at: date)
    }
    guard profile.supportsActiveQuery else {
      guard subscription.name != profile.name || subscription.status != .unsupported else {
        return subscription
      }
      return try updating(
        subscription,
        name: profile.name,
        status: .unsupported,
        at: date
      )
    }

    let status: SubscriptionTrackingStatus =
      subscription.status == .unsupported ? .active : subscription.status
    let fingerprint = try await fingerprinter.fingerprint(for: profile.subscriptionURL)
    guard
      subscription.name != profile.name
        || subscription.urlFingerprint != fingerprint
        || subscription.status != status
    else {
      return subscription
    }
    return try updating(
      subscription,
      name: profile.name,
      urlFingerprint: fingerprint,
      status: status,
      at: date
    )
  }

  private func updating(
    _ subscription: TrackedSubscription,
    name: String? = nil,
    urlFingerprint: String? = nil,
    refreshIntervalMinutes: Int? = nil,
    status: SubscriptionTrackingStatus? = nil,
    at date: Date
  ) throws -> TrackedSubscription {
    try TrackedSubscription(
      id: subscription.id,
      name: name ?? subscription.name,
      identity: subscription.identity,
      urlFingerprint: urlFingerprint ?? subscription.urlFingerprint,
      refreshIntervalMinutes: refreshIntervalMinutes ?? subscription.refreshIntervalMinutes,
      status: status ?? subscription.status,
      createdAt: subscription.createdAt,
      updatedAt: date
    )
  }

  private func profileSubscriptions() async throws -> [TrackedSubscription] {
    try await ledger.subscriptions().filter {
      if case .clashProfile = $0.identity {
        return true
      }
      return false
    }
  }

  private func validateUniqueUIDs(_ subscriptions: [TrackedSubscription]) throws {
    let uids = subscriptions.compactMap(\.identity.clashProfileUID)
    guard Set(uids).count == uids.count else {
      throw ClashProfileTrackingError.multipleSubscriptionsForUID
    }
  }
}

enum ClashProfileTrackingError: Error, Equatable, LocalizedError {
  case unsupportedSubscriptionURL
  case unsupportedRefreshInterval
  case subscriptionNotFound
  case multipleSubscriptionsForUID

  var errorDescription: String? {
    switch self {
    case .unsupportedSubscriptionURL:
      "指定 Profile 只支持 HTTPS 订阅地址。"
    case .unsupportedRefreshInterval:
      "所选查询间隔不受支持。"
    case .subscriptionNotFound:
      "未找到已追踪的 Profile。"
    case .multipleSubscriptionsForUID:
      "同一 Profile UID 存在多个本地订阅，已停止身份映射。"
    }
  }
}
