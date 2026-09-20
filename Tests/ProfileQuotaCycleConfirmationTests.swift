import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class ProfileQuotaCycleConfirmationTests: SQLiteQuotaLedgerTestCase {
  func testConfirmsOnlySelectedProfileAndDisplayedCycleWithoutProxy() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let ledger = SQLiteQuotaLedger(databaseURL: database)
    let start = Date(timeIntervalSince1970: 1_700_800_000)
    let first = try profileSubscription(at: start)
    let second = try profileSubscription(name: "备用订阅", uid: "profile-second", at: start)
    for subscription in [first, second] {
      try await recordReset(subscription: subscription, ledger: ledger, at: start)
    }
    let now = start.addingTimeInterval(120)
    let controller = ProfileQuotaTrackingController(ledger: ledger, now: { now })
    defer { controller.stop() }
    controller.updateTargets(
      [first, second].map { subscription in
        ProfileQuotaTarget(
          subscription: subscription,
          profileUID: subscription.identity.clashProfileUID ?? "",
          subscriptionURL: URL(string: "https://example.com/subscription"),
          isCurrent: subscription.id == first.id,
          availability: .available
        )
      })
    await controller.prepare()
    let firstCycle = try XCTUnwrap(
      controller.snapshot.profiles.first { $0.id == first.id }?.analysis.pendingCycleConfirmation
    )
    let secondCycle = try XCTUnwrap(
      controller.snapshot.profiles.first { $0.id == second.id }?.analysis.pendingCycleConfirmation
    )

    let staleError = await controller.confirmCurrentCycle(
      subscriptionID: second.id,
      cycleID: firstCycle.id
    )
    XCTAssertNotNil(staleError)
    let error = await controller.confirmCurrentCycle(
      subscriptionID: first.id,
      cycleID: firstCycle.id
    )

    XCTAssertNil(error)
    let firstItem = try XCTUnwrap(controller.snapshot.profiles.first { $0.id == first.id })
    let secondItem = try XCTUnwrap(controller.snapshot.profiles.first { $0.id == second.id })
    XCTAssertNil(firstItem.analysis.pendingCycleConfirmation)
    XCTAssertEqual(firstItem.analysis.currentCycle?.id, firstCycle.id)
    XCTAssertEqual(firstItem.queryStatus, .waitingForProxy)
    XCTAssertTrue(
      firstItem.analysis.recentEvents.contains {
        $0.kind == .usageReset && $0.isUserConfirmed
      })
    XCTAssertEqual(secondItem.analysis.pendingCycleConfirmation?.id, secondCycle.id)
    XCTAssertEqual(secondItem.latestQuota?.traffic.usedBytes, 20)
  }

  private func recordReset(
    subscription: TrackedSubscription,
    ledger: SQLiteQuotaLedger,
    at date: Date
  ) async throws {
    _ = try await ledger.upsertSubscription(subscription)
    for (offset, usedBytes) in [UInt64(200), 20].enumerated() {
      _ = try await ledger.record(
        observation(
          subscriptionID: subscription.id,
          at: date.addingTimeInterval(Double(offset) * 60),
          source: .meterActiveQuery,
          usedBytes: usedBytes,
          totalBytes: 1_000
        )
      )
    }
  }
}
