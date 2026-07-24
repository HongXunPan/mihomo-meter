import Foundation

struct AppRelease: Equatable, Sendable {
  let version: SemanticVersion
  let pageURL: URL
}

protocol LatestAppReleaseFetching: Sendable {
  func fetchLatestRelease() async throws -> AppRelease?
}
