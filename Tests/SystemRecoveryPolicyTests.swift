import XCTest

@testable import MihomoMeter

final class SystemRecoveryPolicyTests: XCTestCase {
  func testFirstBlockerPausesAndLastBlockerResumes() {
    var policy = SystemRecoveryPolicy()

    XCTAssertEqual(policy.update(.sleep, isBlocked: true), .pause)
    XCTAssertNil(policy.update(.networkUnavailable, isBlocked: true))
    XCTAssertNil(policy.update(.sleep, isBlocked: false))
    XCTAssertEqual(policy.update(.networkUnavailable, isBlocked: false), .resume)
    XCTAssertTrue(policy.isAvailable)
  }

  func testDuplicateEnvironmentEventDoesNotRepeatAction() {
    var policy = SystemRecoveryPolicy()

    XCTAssertEqual(policy.update(.inactiveSession, isBlocked: true), .pause)
    XCTAssertNil(policy.update(.inactiveSession, isBlocked: true))
    XCTAssertEqual(policy.update(.inactiveSession, isBlocked: false), .resume)
    XCTAssertNil(policy.update(.inactiveSession, isBlocked: false))
  }
}
