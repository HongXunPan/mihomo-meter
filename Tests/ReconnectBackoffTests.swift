import XCTest

@testable import MihomoMeter

final class ReconnectBackoffTests: XCTestCase {
  func testDoublesDelayAndCapsAtThirtySeconds() {
    var backoff = ReconnectBackoff()

    XCTAssertEqual(
      (0..<8).map { _ in backoff.nextDelaySeconds() },
      [1, 2, 4, 8, 16, 30, 30, 30]
    )
  }

  func testResetStartsSequenceAgain() {
    var backoff = ReconnectBackoff()
    _ = backoff.nextDelaySeconds()
    _ = backoff.nextDelaySeconds()

    backoff.reset()

    XCTAssertEqual(backoff.nextDelaySeconds(), 1)
  }
}
