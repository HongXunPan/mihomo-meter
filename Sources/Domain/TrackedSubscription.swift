import Foundation

enum SubscriptionIdentity: Equatable, Sendable {
  case runtimeSingle
  case clashProfile(uid: String)

  var modeRawValue: String {
    switch self {
    case .runtimeSingle:
      "runtime_single"
    case .clashProfile:
      "clash_profile"
    }
  }

  var clashProfileUID: String? {
    switch self {
    case .runtimeSingle:
      nil
    case .clashProfile(let uid):
      uid
    }
  }
}

enum SubscriptionTrackingStatus: String, Equatable, Sendable {
  case active
  case paused
  case archived
  case unsupported
}

struct TrackedSubscription: Identifiable, Equatable, Sendable {
  let id: UUID
  let name: String
  let identity: SubscriptionIdentity
  let urlFingerprint: String?
  let refreshIntervalMinutes: Int?
  let status: SubscriptionTrackingStatus
  let createdAt: Date
  let updatedAt: Date

  init(
    id: UUID,
    name: String,
    identity: SubscriptionIdentity,
    urlFingerprint: String? = nil,
    refreshIntervalMinutes: Int? = nil,
    status: SubscriptionTrackingStatus = .active,
    createdAt: Date,
    updatedAt: Date
  ) throws {
    let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedName.isEmpty else {
      throw QuotaLedgerError.invalidSubscriptionName
    }
    let normalizedIdentity = try Self.normalizedIdentity(identity)
    try Self.validateRefreshInterval(
      refreshIntervalMinutes,
      identity: normalizedIdentity
    )
    guard createdAt <= updatedAt else {
      throw QuotaLedgerError.invalidStoredData
    }

    self.id = id
    self.name = normalizedName
    self.identity = normalizedIdentity
    self.urlFingerprint = urlFingerprint
    self.refreshIntervalMinutes = refreshIntervalMinutes
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  private static func normalizedIdentity(
    _ identity: SubscriptionIdentity
  ) throws -> SubscriptionIdentity {
    guard case .clashProfile(let uid) = identity else {
      return identity
    }
    let normalizedUID = uid.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedUID.isEmpty else {
      throw QuotaLedgerError.invalidProfileUID
    }
    return .clashProfile(uid: normalizedUID)
  }

  private static func validateRefreshInterval(
    _ refreshIntervalMinutes: Int?,
    identity: SubscriptionIdentity
  ) throws {
    switch identity {
    case .runtimeSingle:
      guard refreshIntervalMinutes == nil else {
        throw QuotaLedgerError.invalidRefreshInterval
      }
    case .clashProfile:
      guard let refreshIntervalMinutes, refreshIntervalMinutes >= 60 else {
        throw QuotaLedgerError.invalidRefreshInterval
      }
    }
  }
}
