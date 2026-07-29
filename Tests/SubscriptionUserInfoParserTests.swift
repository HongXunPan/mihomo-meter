import Foundation
import XCTest

@testable import MihomoMeter

final class SubscriptionUserInfoParserTests: XCTestCase {
  func testParsesMihomoCompatibleFieldsAndTruncatesDecimals() throws {
    let result = try SubscriptionUserInfoParser().parse(
      " Upload = 10.9 ; DOWNLOAD=20.2; Total=100; Expire=1800000000 "
    )

    XCTAssertEqual(result.traffic.uploadBytes, 10)
    XCTAssertEqual(result.traffic.downloadBytes, 20)
    XCTAssertEqual(result.traffic.remainingBytes, 70)
    XCTAssertEqual(result.expireAt, Date(timeIntervalSince1970: 1_800_000_000))
  }

  func testIgnoresUnknownFieldsAndKeepsLastRepeatedValue() throws {
    let result = try SubscriptionUserInfoParser().parse(
      "upload=1;download=2;total=10;total=20;web-page=https://example.com"
    )

    XCTAssertEqual(result.traffic.totalBytes, 20)
    XCTAssertEqual(result.traffic.remainingBytes, 17)
    XCTAssertNil(result.expireAt)
  }

  func testRejectsMissingNegativeOverflowAndZeroTotalValues() {
    assertInvalid("upload=1;download=2")
    assertInvalid("upload=-1;download=2;total=10")
    assertInvalid("upload=1;download=2;total=0")
    assertInvalid("upload=9223372036854775808;download=2;total=10")
  }

  private func assertInvalid(_ headerValue: String) {
    XCTAssertThrowsError(try SubscriptionUserInfoParser().parse(headerValue)) { error in
      XCTAssertEqual(error as? ActiveQuotaQueryError, .invalidSubscriptionUserInfo)
    }
  }
}
