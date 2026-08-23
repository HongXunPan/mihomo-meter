import Foundation
import XCTest

@testable import MihomoMeter

final class SystemNotificationPolicyTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private let subscriptionID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let cycleID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

  func testCreatesThreeQuotaDeliveriesAtConfirmedThresholds() throws {
    let input = try makeInput(
      usedBytes: 900,
      expireAt: now.addingTimeInterval(3 * 24 * 60 * 60),
      estimatedDepletionAt: now.addingTimeInterval(60)
    )

    let deliveries = QuotaSystemNotificationPolicy.deliveries(for: [input], at: now)

    XCTAssertEqual(deliveries.count, 3)
    XCTAssertEqual(Set(deliveries.map(\.target)), [.subscriptionQuota])
    XCTAssertEqual(
      Set(deliveries.map(\.deduplicationKey)),
      Set(
        QuotaNotificationKind.allCases.map { kind in
          "quota|\(subscriptionID.uuidString.lowercased())|"
            + "\(cycleID.uuidString.lowercased())|\(kind.rawValue)"
        })
    )
  }

  func testDoesNotNotifyAboveThresholdOrOutsideUpcomingWindow() throws {
    let input = try makeInput(
      usedBytes: 899,
      expireAt: now.addingTimeInterval(3 * 24 * 60 * 60 + 1),
      estimatedDepletionAt: now
    )

    XCTAssertTrue(
      QuotaSystemNotificationPolicy.deliveries(for: [input], at: now).isEmpty
    )
  }

  func testDoesNotNotifyForStaleOrFutureSnapshot() throws {
    let stale = try makeInput(
      observedAt: now.addingTimeInterval(
        -QuotaSystemNotificationPolicy.maximumSnapshotAge - 1
      ),
      usedBytes: 1_000
    )
    let future = try makeInput(
      observedAt: now.addingTimeInterval(1),
      usedBytes: 1_000
    )

    XCTAssertTrue(
      QuotaSystemNotificationPolicy.deliveries(for: [stale, future], at: now).isEmpty
    )
  }

  func testDeduplicationKeyChangesWithCycleAndKind() throws {
    let first = try makeInput(usedBytes: 1_000)
    let second = try QuotaNotificationInput(
      subscriptionID: subscriptionID,
      cycleID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
      isCurrentCycleConfirmed: true,
      observedAt: now,
      traffic: QuotaTraffic(uploadBytes: 500, downloadBytes: 500, totalBytes: 1_000),
      expireAt: now.addingTimeInterval(60),
      estimatedDepletionAt: nil
    )

    let keys = Set(
      QuotaSystemNotificationPolicy.deliveries(for: [first, second], at: now)
        .map(\.deduplicationKey)
    )

    XCTAssertEqual(keys.count, 3)
  }

  func testDoesNotNotifyForUnconfirmedCurrentCycle() throws {
    let input = try makeInput(
      usedBytes: 1_000,
      isCurrentCycleConfirmed: false
    )

    XCTAssertTrue(
      QuotaSystemNotificationPolicy.deliveries(for: [input], at: now).isEmpty
    )
  }

  func testSustainedDisconnectionRequiresTenMinutes() {
    let startedAt = now.addingTimeInterval(-10 * 60)

    XCTAssertFalse(
      ConnectionSystemNotificationPolicy.shouldNotify(
        disconnectedSince: startedAt,
        at: now.addingTimeInterval(-1)
      )
    )
    XCTAssertTrue(
      ConnectionSystemNotificationPolicy.shouldNotify(
        disconnectedSince: startedAt,
        at: now
      )
    )
    XCTAssertFalse(
      ConnectionSystemNotificationPolicy.shouldNotify(disconnectedSince: nil, at: now)
    )
  }

  private func makeInput(
    observedAt: Date? = nil,
    usedBytes: UInt64,
    expireAt: Date? = nil,
    estimatedDepletionAt: Date? = nil,
    isCurrentCycleConfirmed: Bool = true
  ) throws -> QuotaNotificationInput {
    QuotaNotificationInput(
      subscriptionID: subscriptionID,
      cycleID: cycleID,
      isCurrentCycleConfirmed: isCurrentCycleConfirmed,
      observedAt: observedAt ?? now,
      traffic: try QuotaTraffic(
        uploadBytes: usedBytes / 2,
        downloadBytes: usedBytes - usedBytes / 2,
        totalBytes: 1_000
      ),
      expireAt: expireAt,
      estimatedDepletionAt: estimatedDepletionAt
    )
  }
}
