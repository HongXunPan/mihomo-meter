import Combine
import Foundation

enum AppUpdateState: Equatable {
  case idle
  case checking
  case upToDate
  case noRelease
  case updateAvailable(AppRelease)
  case failed
}

@MainActor
final class AppUpdateModel: ObservableObject {
  @Published private(set) var state: AppUpdateState = .idle

  let currentVersionText: String

  private let currentVersion: SemanticVersion?
  private let releaseClient: any LatestAppReleaseFetching
  private var checkTask: Task<Void, Never>?

  convenience init() {
    self.init(
      currentVersionString: Self.bundleVersion(),
      releaseClient: GitHubReleaseClient()
    )
  }

  init(
    currentVersionString: String,
    releaseClient: any LatestAppReleaseFetching
  ) {
    currentVersionText = currentVersionString
    currentVersion = SemanticVersion(currentVersionString)
    self.releaseClient = releaseClient
  }

  func checkForUpdates() {
    guard checkTask == nil else {
      return
    }
    guard let currentVersion else {
      state = .failed
      return
    }

    state = .checking
    checkTask = Task { [weak self] in
      guard let self else {
        return
      }

      do {
        let release = try await releaseClient.fetchLatestRelease()
        guard !Task.isCancelled else {
          return
        }

        switch release {
        case .some(let release) where release.version > currentVersion:
          state = .updateAvailable(release)
        case .some:
          state = .upToDate
        case .none:
          state = .noRelease
        }
      } catch is CancellationError {
        return
      } catch {
        state = .failed
      }
      checkTask = nil
    }
  }

  func cancel() {
    checkTask?.cancel()
    checkTask = nil
  }

  private static func bundleVersion(bundle: Bundle = .main) -> String {
    bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "开发版"
  }
}
