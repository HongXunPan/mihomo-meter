import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class QuotaCycleConfirmationStateTests: XCTestCase {
  func testDoesNotConfirmWithoutExplicitAction() {
    let state = QuotaCycleConfirmationState()

    XCTAssertFalse(state.isConfirming)
    XCTAssertNil(state.errorMessage)
  }

  func testFailureKeepsErrorAndAllowsExplicitRetry() async {
    let state = QuotaCycleConfirmationState()
    var attempts = 0

    await state.confirm {
      attempts += 1
      return "账本暂不可写"
    }

    XCTAssertEqual(attempts, 1)
    XCTAssertFalse(state.isConfirming)
    XCTAssertEqual(state.errorMessage, "确认失败：账本暂不可写")

    await state.confirm {
      XCTAssertNil(state.errorMessage)
      attempts += 1
      return nil
    }

    XCTAssertEqual(attempts, 2)
    XCTAssertFalse(state.isConfirming)
    XCTAssertNil(state.errorMessage)
  }

  func testIgnoresRepeatedActionWhileConfirmationIsRunning() async {
    let state = QuotaCycleConfirmationState()
    var attempts = 0

    await state.confirm {
      attempts += 1
      XCTAssertTrue(state.isConfirming)
      await state.confirm {
        attempts += 1
        return nil
      }
      return nil
    }

    XCTAssertEqual(attempts, 1)
    XCTAssertFalse(state.isConfirming)
  }
}
