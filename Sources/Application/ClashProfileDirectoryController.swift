import Combine
import Foundation

@MainActor
final class ClashProfileDirectoryController: ObservableObject {
  @Published private(set) var snapshot = ClashProfileDirectorySnapshot.loading

  private let authorizer: any ProfileDirectoryAuthorizing
  private let bookmarkStore: any ProfileDirectoryBookmarkStoring
  private let securityScope: any ProfileDirectorySecurityScoping
  private let reader: any ClashProfileCatalogReading
  private let observer: any ProfileDirectoryObserving
  private let trackingService: ClashProfileTrackingService
  private let profileQuotaLifecycle: any ProfileQuotaTrackingLifecycle
  private let now: @MainActor () -> Date

  private var activeDirectoryURL: URL?
  private var catalog: ClashProfileCatalog?
  private var subscriptions: [TrackedSubscription] = []

  init(
    authorizer: any ProfileDirectoryAuthorizing,
    bookmarkStore: any ProfileDirectoryBookmarkStoring,
    securityScope: any ProfileDirectorySecurityScoping,
    reader: any ClashProfileCatalogReading,
    observer: any ProfileDirectoryObserving,
    trackingService: ClashProfileTrackingService,
    profileQuotaLifecycle: any ProfileQuotaTrackingLifecycle =
      NoOpProfileQuotaTrackingLifecycle.shared,
    now: @escaping @MainActor () -> Date = Date.init
  ) {
    self.authorizer = authorizer
    self.bookmarkStore = bookmarkStore
    self.securityScope = securityScope
    self.reader = reader
    self.observer = observer
    self.trackingService = trackingService
    self.profileQuotaLifecycle = profileQuotaLifecycle
    self.now = now
  }

  func prepare() async {
    do {
      subscriptions = try await trackingService.prepare()
      guard let bookmark = bookmarkStore.loadBookmark() else {
        apply(accessStatus: .notAuthorized)
        return
      }
      let resolution = try securityScope.resolveBookmark(bookmark)
      try await activate(
        directoryURL: resolution.directoryURL,
        shouldRefreshBookmark: resolution.isStale
      )
    } catch {
      apply(accessStatus: .needsReauthorization)
    }
  }

  func authorizeDirectory() async {
    guard let directoryURL = authorizer.chooseDirectory() else {
      return
    }
    do {
      try await activate(directoryURL: directoryURL, shouldRefreshBookmark: true)
    } catch {
      apply(accessStatus: .failed(publicMessage(for: error)))
    }
  }

  func reload() async {
    guard let activeDirectoryURL else {
      return
    }
    do {
      let catalog = try reader.readCatalog(in: activeDirectoryURL)
      subscriptions = try await trackingService.reconcile(catalog: catalog, at: now())
      self.catalog = catalog
      apply(accessStatus: .available)
    } catch {
      apply(accessStatus: .failed(publicMessage(for: error)))
    }
  }

  func setTracking(_ isSelected: Bool, profileUID: String) async {
    do {
      if isSelected {
        guard let profile = catalog?.profiles.first(where: { $0.uid == profileUID }) else {
          return
        }
        subscriptions = try await trackingService.setTracking(profile: profile, at: now())
      } else {
        subscriptions = try await trackingService.removeTracking(
          profileUID: profileUID,
          at: now()
        )
      }
      apply(accessStatus: .available)
    } catch {
      apply(accessStatus: .failed(publicMessage(for: error)))
    }
  }

  func setRefreshInterval(_ intervalMinutes: Int, profileUID: String) async {
    do {
      subscriptions = try await trackingService.setRefreshInterval(
        intervalMinutes,
        profileUID: profileUID,
        at: now()
      )
      apply(accessStatus: .available)
    } catch {
      apply(accessStatus: .failed(publicMessage(for: error)))
    }
  }

  func revokeDirectoryAccess() {
    stop()
    bookmarkStore.deleteBookmark()
    catalog = nil
    apply(accessStatus: .notAuthorized)
  }

  func resetTrackingAfterQuotaClear() {
    subscriptions = []
    apply(accessStatus: snapshot.accessStatus)
  }

  func republishTrackingTargets() {
    apply(accessStatus: snapshot.accessStatus)
  }

  func stop() {
    observer.stopObserving()
    if let activeDirectoryURL {
      securityScope.stopAccessing(activeDirectoryURL)
      self.activeDirectoryURL = nil
    }
  }

  private func activate(
    directoryURL: URL,
    shouldRefreshBookmark: Bool
  ) async throws {
    guard securityScope.startAccessing(directoryURL) else {
      throw ClashProfileDirectoryControllerError.cannotAccessDirectory
    }

    let catalog: ClashProfileCatalog
    let subscriptions: [TrackedSubscription]
    let refreshedBookmark: Data?
    do {
      catalog = try reader.readCatalog(in: directoryURL)
      subscriptions = try await trackingService.reconcile(catalog: catalog, at: now())
      refreshedBookmark =
        try shouldRefreshBookmark
        ? securityScope.makeReadOnlyBookmark(for: directoryURL)
        : nil
    } catch {
      securityScope.stopAccessing(directoryURL)
      throw error
    }

    observer.stopObserving()
    if let activeDirectoryURL {
      securityScope.stopAccessing(activeDirectoryURL)
      self.activeDirectoryURL = nil
    }
    do {
      try observer.startObserving(directoryURL: directoryURL) { [weak self] in
        Task { @MainActor [weak self] in
          await self?.reload()
        }
      }
    } catch {
      securityScope.stopAccessing(directoryURL)
      throw error
    }

    activeDirectoryURL = directoryURL
    self.catalog = catalog
    self.subscriptions = subscriptions
    if let refreshedBookmark {
      bookmarkStore.saveBookmark(refreshedBookmark)
    }
    apply(accessStatus: .available)
  }

  private func apply(accessStatus: ProfileDirectoryAccessStatus) {
    let rows = ClashProfileSelectionBuilder().build(
      catalog: catalog,
      subscriptions: subscriptions
    )
    snapshot = ClashProfileDirectorySnapshot(
      accessStatus: accessStatus,
      profiles: rows,
      ignoredRemoteProfileCount: catalog?.ignoredRemoteProfileCount ?? 0,
      trackedProfileCount: rows.filter(\.isSelected).count
    )
    profileQuotaLifecycle.updateTargets(
      ProfileQuotaTargetBuilder().build(catalog: catalog, subscriptions: subscriptions)
    )
  }

  private func publicMessage(for error: any Error) -> String {
    switch error {
    case let error as ClashProfileCatalogReaderError:
      error.localizedDescription
    case let error as ClashProfileTrackingError:
      error.localizedDescription
    case let error as ClashProfileDirectoryControllerError:
      error.localizedDescription
    case let error as ProfileDirectoryObserverError:
      error.localizedDescription
    default:
      "Profile 目录处理失败。"
    }
  }
}

enum ClashProfileDirectoryControllerError: Error, Equatable, LocalizedError {
  case cannotAccessDirectory

  var errorDescription: String? {
    "无法取得所选 Profile 目录的只读权限。"
  }
}
