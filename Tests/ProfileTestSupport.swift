import Foundation
import XCTest

@testable import MihomoMeter

func testClashProfile(
  uid: String = "profile-a",
  name: String = "测试订阅",
  url: String = "https://example.com/sub?token=test"
) throws -> ClashProfile {
  try ClashProfile(
    uid: uid,
    name: name,
    subscriptionURL: XCTUnwrap(URL(string: url))
  )
}

func testProfileTrackingService(
  ledger: any QuotaLedgerStoring
) -> ClashProfileTrackingService {
  ClashProfileTrackingService(
    ledger: ledger,
    fingerprinter: HMACProfileURLFingerprinter(
      keyStore: TestProfileFingerprintKeyStore()
    )
  )
}

actor TestProfileFingerprintKeyStore: ProfileFingerprintKeyStoring {
  func loadOrCreateKey() async throws -> Data {
    Data(repeating: 9, count: 32)
  }
}

final class TestClashProfileCatalogReader: ClashProfileCatalogReading, @unchecked Sendable {
  private let lock = NSLock()
  private var catalog: ClashProfileCatalog

  init(catalog: ClashProfileCatalog) {
    self.catalog = catalog
  }

  func readCatalog(in directoryURL: URL) throws -> ClashProfileCatalog {
    lock.withLock { catalog }
  }

  func setCatalog(_ catalog: ClashProfileCatalog) {
    lock.withLock {
      self.catalog = catalog
    }
  }
}

@MainActor
final class TestProfileDirectoryAuthorizer: ProfileDirectoryAuthorizing {
  var selectedURL: URL?

  init(selectedURL: URL? = nil) {
    self.selectedURL = selectedURL
  }

  func chooseDirectory() -> URL? {
    selectedURL
  }
}

@MainActor
final class TestProfileDirectoryBookmarkStore: ProfileDirectoryBookmarkStoring {
  var bookmark: Data?
  private(set) var savedBookmarks: [Data] = []

  init(bookmark: Data? = nil) {
    self.bookmark = bookmark
  }

  func loadBookmark() -> Data? {
    bookmark
  }

  func saveBookmark(_ bookmark: Data) {
    self.bookmark = bookmark
    savedBookmarks.append(bookmark)
  }

  func deleteBookmark() {
    bookmark = nil
  }
}

@MainActor
final class TestProfileDirectorySecurityScope: ProfileDirectorySecurityScoping {
  var resolution: ProfileDirectoryBookmarkResolution
  var canStartAccessing = true
  var createdBookmark = Data("refreshed".utf8)
  private(set) var startedURLs: [URL] = []
  private(set) var stoppedURLs: [URL] = []

  init(directoryURL: URL, isStale: Bool = false) {
    resolution = ProfileDirectoryBookmarkResolution(
      directoryURL: directoryURL,
      isStale: isStale
    )
  }

  func makeReadOnlyBookmark(for directoryURL: URL) throws -> Data {
    createdBookmark
  }

  func resolveBookmark(_ bookmark: Data) throws -> ProfileDirectoryBookmarkResolution {
    resolution
  }

  func startAccessing(_ directoryURL: URL) -> Bool {
    startedURLs.append(directoryURL)
    return canStartAccessing
  }

  func stopAccessing(_ directoryURL: URL) {
    stoppedURLs.append(directoryURL)
  }
}

@MainActor
final class TestProfileDirectoryObserver: ProfileDirectoryObserving {
  private(set) var observedURL: URL?
  private var onChange: (@MainActor () -> Void)?

  func startObserving(
    directoryURL: URL,
    onChange: @escaping @MainActor () -> Void
  ) throws {
    observedURL = directoryURL
    self.onChange = onChange
  }

  func stopObserving() {
    observedURL = nil
    onChange = nil
  }

  func sendChange() {
    onChange?()
  }
}
