import Foundation

struct ClashProfile: Identifiable, Equatable, Sendable {
  let uid: String
  let name: String
  let subscriptionURL: URL

  var id: String {
    uid
  }

  var subscriptionDomain: String {
    subscriptionURL.host()?.lowercased() ?? "未知域名"
  }

  var supportsActiveQuery: Bool {
    subscriptionURL.scheme?.lowercased() == "https"
  }

  init(uid: String, name: String, subscriptionURL: URL) throws {
    let normalizedUID = uid.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let scheme = subscriptionURL.scheme?.lowercased()

    guard !normalizedUID.isEmpty else {
      throw ClashProfileError.invalidUID
    }
    guard !normalizedName.isEmpty else {
      throw ClashProfileError.invalidName
    }
    guard
      scheme == "http" || scheme == "https",
      subscriptionURL.host() != nil
    else {
      throw ClashProfileError.invalidSubscriptionURL
    }

    self.uid = normalizedUID
    self.name = normalizedName
    self.subscriptionURL = subscriptionURL
  }
}

struct ClashProfileCatalog: Equatable, Sendable {
  let currentUID: String?
  let profiles: [ClashProfile]
  let ignoredRemoteProfileCount: Int

  var currentProfile: ClashProfile? {
    guard let currentUID else {
      return nil
    }
    return profiles.first { $0.uid == currentUID }
  }
}

enum ClashProfileError: Error, Equatable, LocalizedError {
  case invalidUID
  case invalidName
  case invalidSubscriptionURL

  var errorDescription: String? {
    switch self {
    case .invalidUID:
      "Profile UID 无效。"
    case .invalidName:
      "Profile 名称无效。"
    case .invalidSubscriptionURL:
      "Profile 订阅地址无效。"
    }
  }
}
