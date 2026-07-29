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

  func testPrefersStandardSubscriptionUserInfoHeader() throws {
    let response = try response(
      headers: [
        "Subscription-Userinfo": "upload=1; download=2; total=100",
        "X-Amz-Meta-Subscription-Userinfo": "upload=9; download=9; total=100",
      ]
    )

    XCTAssertEqual(
      MihomoActiveQuotaQueryClient().subscriptionUserInfoHeader(in: response),
      "upload=1; download=2; total=100"
    )
  }

  func testAcceptsMetadataPrefixedSubscriptionUserInfoHeader() throws {
    let response = try response(
      headers: [
        "X-Obs-Meta-Subscription-Userinfo": "upload=3; download=4; total=100"
      ]
    )

    XCTAssertEqual(
      MihomoActiveQuotaQueryClient().subscriptionUserInfoHeader(in: response),
      "upload=3; download=4; total=100"
    )
  }

  func testDoesNotAcceptUnrelatedSubscriptionHeader() throws {
    let response = try response(
      headers: ["X-Subscription-Info": "upload=3; download=4; total=100"]
    )

    XCTAssertNil(MihomoActiveQuotaQueryClient().subscriptionUserInfoHeader(in: response))
  }

  func testNormalizesNSErrorTimeoutWithoutRawErrorText() {
    let client = MihomoActiveQuotaQueryClient(timeout: 15)
    let error = NSError(
      domain: NSURLErrorDomain,
      code: URLError.Code.timedOut.rawValue,
      userInfo: [NSLocalizedDescriptionKey: "包含敏感地址的原始错误"]
    )

    XCTAssertEqual(
      client.normalizedTransportError(error),
      .timedOut(timeoutSeconds: 15)
    )
  }

  func testNormalizesWrappedNetworkError() {
    let underlyingError = NSError(
      domain: NSURLErrorDomain,
      code: URLError.Code.cannotConnectToHost.rawValue
    )
    let wrappedError = NSError(
      domain: "MihomoMeterTests",
      code: 1,
      userInfo: [NSUnderlyingErrorKey: underlyingError]
    )

    XCTAssertEqual(
      MihomoActiveQuotaQueryClient().normalizedTransportError(wrappedError),
      .network(.cannotConnectToHost)
    )
  }

  func testKeepsUnknownTransportErrorGeneric() {
    let error = NSError(domain: "MihomoMeterTests", code: 2)

    XCTAssertEqual(
      MihomoActiveQuotaQueryClient().normalizedTransportError(error),
      .transport
    )
  }

  private func response(headers: [String: String]) throws -> HTTPURLResponse {
    try XCTUnwrap(
      HTTPURLResponse(
        url: XCTUnwrap(URL(string: "https://example.com/subscription")),
        statusCode: 200,
        httpVersion: nil,
        headerFields: headers
      )
    )
  }
}
