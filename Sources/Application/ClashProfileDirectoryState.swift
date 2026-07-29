import Foundation

enum ProfileDirectoryAccessStatus: Equatable, Sendable {
  case loading
  case notAuthorized
  case available
  case needsReauthorization
  case failed(String)
}

enum ClashProfileAvailability: Equatable, Sendable {
  case available
  case unsupportedURL
  case missing
}

struct ClashProfileSelectionItem: Identifiable, Equatable, Sendable {
  let uid: String
  let name: String
  let subscriptionDomain: String?
  let isCurrent: Bool
  let isSelected: Bool
  let refreshIntervalMinutes: Int?
  let availability: ClashProfileAvailability

  var id: String {
    uid
  }
}

struct ClashProfileDirectorySnapshot: Equatable, Sendable {
  var accessStatus = ProfileDirectoryAccessStatus.loading
  var profiles: [ClashProfileSelectionItem] = []
  var ignoredRemoteProfileCount = 0
  var trackedProfileCount = 0

  static let loading = ClashProfileDirectorySnapshot()

  var selectedProfiles: [ClashProfileSelectionItem] {
    profiles.filter(\.isSelected)
  }
}
