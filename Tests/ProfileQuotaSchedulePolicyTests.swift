import Foundation
import XCTest

@testable import MihomoMeter

final class ProfileQuotaSchedulePolicyTests: SQLiteQuotaLedgerTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
  }

  func testURLChangeIsDueImmediatelyWhileRenameKeepsSchedule() throws {
    let now = Date(timeIntervalSince1970: 1_700_700_000)
    let subscription = try profileSubscription(at: now)
    let policy = ProfileQuotaSchedulePolicy(calendar: calendar)
    let state = ProfileQuotaQueryState(
      subscriptionID: subscription.id,
      lastAttemptAt: now,
      nextAttemptAt: now.addingTimeInterval(3_600),
      lastQueriedURLFingerprint: subscription.urlFingerprint,
      consecutiveFailures: 0,
      retryDayStart: nil,
      automaticRetryCount: 0
    )
    let renamed = try TrackedSubscription(
      id: subscription.id,
      name: "改名后的 Profile",
      identity: subscription.identity,
      urlFingerprint: subscription.urlFingerprint,
      refreshIntervalMinutes: subscription.refreshIntervalMinutes,
      createdAt: subscription.createdAt,
      updatedAt: now.addingTimeInterval(1)
    )
    let changedURL = try TrackedSubscription(
      id: subscription.id,
      name: renamed.name,
      identity: subscription.identity,
      urlFingerprint: "fingerprint-changed",
      refreshIntervalMinutes: subscription.refreshIntervalMinutes,
      createdAt: subscription.createdAt,
      updatedAt: now.addingTimeInterval(2)
    )

    XCTAssertEqual(policy.dueDate(for: renamed, state: state, now: now), state.nextAttemptAt)
    XCTAssertEqual(policy.dueDate(for: changedURL, state: state, now: now), now)
  }

  func testSuccessUsesIndependentIntervalAndJitter() throws {
    let now = Date(timeIntervalSince1970: 1_700_710_000)
    let subscription = try profileSubscription(intervalMinutes: 180, at: now)
    let state = ProfileQuotaSchedulePolicy(calendar: calendar).successfulState(
      for: subscription,
      at: now,
      jitter: 30
    )

    XCTAssertEqual(state.nextAttemptAt, now.addingTimeInterval(10_830))
    XCTAssertEqual(state.lastQueriedURLFingerprint, subscription.urlFingerprint)
    XCTAssertEqual(state.consecutiveFailures, 0)
  }

  func testFailureBackoffStopsAfterThreeAutomaticRetries() throws {
    let policy = ProfileQuotaSchedulePolicy(calendar: calendar)
    let start = Date(timeIntervalSince1970: 1_700_720_000)
    let subscription = try profileSubscription(intervalMinutes: 60, at: start)

    let initialFailure = policy.failedState(
      for: subscription,
      previous: nil,
      trigger: .automatic,
      at: start,
      jitter: 0
    )
    let firstRetry = policy.failedState(
      for: subscription,
      previous: initialFailure,
      trigger: .automatic,
      at: start.addingTimeInterval(300),
      jitter: 0
    )
    let secondRetry = policy.failedState(
      for: subscription,
      previous: firstRetry,
      trigger: .automatic,
      at: start.addingTimeInterval(1_200),
      jitter: 0
    )
    let thirdRetry = policy.failedState(
      for: subscription,
      previous: secondRetry,
      trigger: .automatic,
      at: start.addingTimeInterval(4_800),
      jitter: 30
    )

    XCTAssertEqual(initialFailure.nextAttemptAt, start.addingTimeInterval(300))
    XCTAssertEqual(firstRetry.automaticRetryCount, 1)
    XCTAssertEqual(firstRetry.nextAttemptAt, start.addingTimeInterval(1_200))
    XCTAssertEqual(secondRetry.automaticRetryCount, 2)
    XCTAssertEqual(secondRetry.nextAttemptAt, start.addingTimeInterval(4_800))
    XCTAssertEqual(thirdRetry.automaticRetryCount, 3)
    XCTAssertEqual(thirdRetry.consecutiveFailures, 0)
    XCTAssertEqual(thirdRetry.nextAttemptAt, start.addingTimeInterval(8_430))
  }
}
