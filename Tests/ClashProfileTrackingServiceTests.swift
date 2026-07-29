import Foundation
import XCTest

@testable import MihomoMeter

final class ClashProfileTrackingServiceTests: SQLiteQuotaLedgerTestCase {
  func testSelectsProfileWithoutPersistingRawURLOrQuotaSnapshot() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let ledger = SQLiteQuotaLedger(databaseURL: database)
    let service = testProfileTrackingService(ledger: ledger)
    let date = Date(timeIntervalSince1970: 1_702_000_000)
    let profile = try testClashProfile()

    _ = try await service.prepare()
    let subscriptions = try await service.setTracking(profile: profile, at: date)

    let subscription = try XCTUnwrap(subscriptions.first)
    XCTAssertEqual(subscription.identity, .clashProfile(uid: profile.uid))
    XCTAssertEqual(subscription.refreshIntervalMinutes, 360)
    XCTAssertEqual(subscription.status, .active)
    XCTAssertFalse(try XCTUnwrap(subscription.urlFingerprint).contains("example.com"))
    let latestSnapshot = try await ledger.latestSnapshot(for: subscription.id)
    XCTAssertNil(latestSnapshot)
  }

  func testRenameAndURLResetKeepIdentityAndHistory() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let ledger = SQLiteQuotaLedger(databaseURL: database)
    let service = testProfileTrackingService(ledger: ledger)
    let start = Date(timeIntervalSince1970: 1_702_100_000)
    let original = try testClashProfile()

    _ = try await service.prepare()
    let selected = try await service.setTracking(profile: original, at: start)
    let originalSubscription = try XCTUnwrap(selected.first)
    _ = try await ledger.record(
      try observation(
        subscriptionID: originalSubscription.id,
        at: start.addingTimeInterval(10),
        source: .meterActiveQuery,
        usedBytes: 100,
        totalBytes: 1_000
      )
    )
    let changed = try testClashProfile(
      name: "改名后的订阅",
      url: "https://new.example.com/sub?token=changed"
    )

    let reconciled = try await service.reconcile(
      catalog: ClashProfileCatalog(
        currentUID: changed.uid,
        profiles: [changed],
        ignoredRemoteProfileCount: 0
      ),
      at: start.addingTimeInterval(20)
    )

    let updated = try XCTUnwrap(reconciled.first)
    XCTAssertEqual(updated.id, originalSubscription.id)
    XCTAssertEqual(updated.name, "改名后的订阅")
    XCTAssertNotEqual(updated.urlFingerprint, originalSubscription.urlFingerprint)
    let latestSnapshot = try await ledger.latestSnapshot(for: updated.id)
    XCTAssertNotNil(latestSnapshot)
  }

  func testDeleteAndReimportWithNewUIDDoesNotInheritHistory() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let ledger = SQLiteQuotaLedger(databaseURL: database)
    let service = testProfileTrackingService(ledger: ledger)
    let start = Date(timeIntervalSince1970: 1_702_200_000)
    let original = try testClashProfile(uid: "old-uid")

    _ = try await service.prepare()
    let selected = try await service.setTracking(profile: original, at: start)
    let oldSubscription = try XCTUnwrap(selected.first)
    let missing = try await service.reconcile(
      catalog: ClashProfileCatalog(
        currentUID: nil,
        profiles: [],
        ignoredRemoteProfileCount: 0
      ),
      at: start.addingTimeInterval(10)
    )
    XCTAssertEqual(missing.first?.status, .unsupported)

    let imported = try testClashProfile(uid: "new-uid", name: "重新导入")
    let afterImport = try await service.reconcile(
      catalog: ClashProfileCatalog(
        currentUID: imported.uid,
        profiles: [imported],
        ignoredRemoteProfileCount: 0
      ),
      at: start.addingTimeInterval(20)
    )
    XCTAssertEqual(afterImport.count, 1)
    XCTAssertEqual(afterImport.first?.id, oldSubscription.id)

    let afterSelection = try await service.setTracking(
      profile: imported,
      at: start.addingTimeInterval(30)
    )
    XCTAssertEqual(afterSelection.count, 2)
    XCTAssertNotEqual(
      afterSelection.first { $0.identity == .clashProfile(uid: imported.uid) }?.id,
      oldSubscription.id
    )
  }
}
