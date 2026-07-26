import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class ClashProfileDirectoryControllerTests: SQLiteQuotaLedgerTestCase {
  func testPrepareWithoutBookmarkDoesNotRequestDirectoryAccess() async throws {
    let context = try makeContext(bookmark: nil)
    defer { removeDatabase(at: context.database) }

    await context.controller.prepare()

    XCTAssertEqual(context.controller.snapshot.accessStatus, .notAuthorized)
    XCTAssertTrue(context.securityScope.startedURLs.isEmpty)
    XCTAssertNil(context.observer.observedURL)
  }

  func testRestoresBookmarkAndRefreshesItOnlyWhenStale() async throws {
    let context = try makeContext(bookmark: Data("stored".utf8), isStale: true)
    defer { removeDatabase(at: context.database) }

    await context.controller.prepare()

    XCTAssertEqual(context.controller.snapshot.accessStatus, .available)
    XCTAssertEqual(context.securityScope.startedURLs, [context.directory])
    XCTAssertEqual(context.observer.observedURL, context.directory)
    XCTAssertEqual(context.bookmarkStore.savedBookmarks, [Data("refreshed".utf8)])
  }

  func testRestoresCurrentBookmarkWithoutSavingItAgain() async throws {
    let context = try makeContext(bookmark: Data("stored".utf8))
    defer { removeDatabase(at: context.database) }

    await context.controller.prepare()
    context.controller.stop()

    XCTAssertEqual(context.controller.snapshot.accessStatus, .available)
    XCTAssertTrue(context.bookmarkStore.savedBookmarks.isEmpty)
    XCTAssertEqual(context.securityScope.startedURLs, [context.directory])
    XCTAssertEqual(context.securityScope.stoppedURLs, [context.directory])
  }

  func testAuthorizationSelectsCurrentProfileAndPairsScopeOnRevoke() async throws {
    let context = try makeContext(bookmark: nil)
    defer { removeDatabase(at: context.database) }

    await context.controller.prepare()
    await context.controller.authorizeDirectory()
    await context.controller.setTracking(true, profileUID: "profile-a")

    let current = try XCTUnwrap(context.controller.snapshot.profiles.first)
    XCTAssertTrue(current.isCurrent)
    XCTAssertTrue(current.isSelected)
    XCTAssertEqual(current.refreshIntervalMinutes, 360)

    context.controller.revokeDirectoryAccess()

    XCTAssertEqual(context.securityScope.stoppedURLs, [context.directory])
    XCTAssertNil(context.bookmarkStore.bookmark)
  }

  func testDirectoryChangeUpdatesNameWithoutCreatingSnapshot() async throws {
    let context = try makeContext(bookmark: Data("stored".utf8))
    defer { removeDatabase(at: context.database) }

    await context.controller.prepare()
    await context.controller.setTracking(true, profileUID: "profile-a")
    context.reader.setCatalog(
      ClashProfileCatalog(
        currentUID: "profile-a",
        profiles: [try testClashProfile(name: "新名称")],
        ignoredRemoteProfileCount: 0
      )
    )
    await context.controller.reload()

    let selected = try XCTUnwrap(context.controller.snapshot.selectedProfiles.first)
    XCTAssertEqual(selected.name, "新名称")
    let subscriptions = try await context.ledger.subscriptions()
    let subscription = try XCTUnwrap(
      subscriptions.first {
        $0.identity == .clashProfile(uid: "profile-a")
      })
    let latestSnapshot = try await context.ledger.latestSnapshot(for: subscription.id)
    XCTAssertNil(latestSnapshot)
  }

  func testSelectsNoncurrentProfileAndStoresMeterInterval() async throws {
    let current = try testClashProfile(uid: "current", name: "当前订阅")
    let secondary = try testClashProfile(
      uid: "secondary",
      name: "备用订阅",
      url: "https://secondary.example/sub"
    )
    let context = try makeContext(
      bookmark: Data("stored".utf8),
      catalog: ClashProfileCatalog(
        currentUID: current.uid,
        profiles: [secondary, current],
        ignoredRemoteProfileCount: 0
      )
    )
    defer { removeDatabase(at: context.database) }

    await context.controller.prepare()
    await context.controller.setTracking(true, profileUID: secondary.uid)
    await context.controller.setRefreshInterval(180, profileUID: secondary.uid)

    XCTAssertEqual(context.controller.snapshot.profiles.first?.uid, current.uid)
    let selected = try XCTUnwrap(
      context.controller.snapshot.profiles.first { $0.uid == secondary.uid }
    )
    XCTAssertFalse(selected.isCurrent)
    XCTAssertTrue(selected.isSelected)
    XCTAssertEqual(selected.refreshIntervalMinutes, 180)
  }

  private func makeContext(
    bookmark: Data?,
    isStale: Bool = false,
    catalog: ClashProfileCatalog? = nil
  ) throws -> ProfileDirectoryControllerTestContext {
    let database = temporaryDatabase()
    let ledger = SQLiteQuotaLedger(databaseURL: database)
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("MihomoMeterProfileControllerTests")
    let resolvedCatalog =
      try catalog
      ?? ClashProfileCatalog(
        currentUID: "profile-a",
        profiles: [testClashProfile()],
        ignoredRemoteProfileCount: 0
      )
    let reader = TestClashProfileCatalogReader(catalog: resolvedCatalog)
    let authorizer = TestProfileDirectoryAuthorizer(selectedURL: directory)
    let bookmarkStore = TestProfileDirectoryBookmarkStore(bookmark: bookmark)
    let securityScope = TestProfileDirectorySecurityScope(
      directoryURL: directory,
      isStale: isStale
    )
    let observer = TestProfileDirectoryObserver()
    let controller = ClashProfileDirectoryController(
      authorizer: authorizer,
      bookmarkStore: bookmarkStore,
      securityScope: securityScope,
      reader: reader,
      observer: observer,
      trackingService: testProfileTrackingService(ledger: ledger),
      now: { Date(timeIntervalSince1970: 1_702_300_000) }
    )
    return ProfileDirectoryControllerTestContext(
      database: database,
      directory: directory,
      ledger: ledger,
      reader: reader,
      bookmarkStore: bookmarkStore,
      securityScope: securityScope,
      observer: observer,
      controller: controller
    )
  }
}

@MainActor
private struct ProfileDirectoryControllerTestContext {
  let database: URL
  let directory: URL
  let ledger: SQLiteQuotaLedger
  let reader: TestClashProfileCatalogReader
  let bookmarkStore: TestProfileDirectoryBookmarkStore
  let securityScope: TestProfileDirectorySecurityScope
  let observer: TestProfileDirectoryObserver
  let controller: ClashProfileDirectoryController
}
