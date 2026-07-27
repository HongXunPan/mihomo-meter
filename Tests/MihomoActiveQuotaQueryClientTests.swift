import Foundation
import XCTest

@testable import MihomoMeter

final class MihomoActiveQuotaQueryClientTests: XCTestCase {
  func testBuildsRequestWithExplicitUserAgent() throws {
    let url = try XCTUnwrap(URL(string: "https://example.com/subscription"))

    let request = MihomoActiveQuotaQueryClient().makeRequest(
      subscriptionURL: url,
      userAgent: "mihomo-test-agent"
    )

    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "*/*")
    XCTAssertEqual(
      request.value(forHTTPHeaderField: "User-Agent"),
      "mihomo-test-agent"
    )
  }
}
