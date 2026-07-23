import XCTest

@testable import MihomoMeter

final class ControllerEndpointTests: XCTestCase {
  func testNormalizesLoopbackAddressWithoutScheme() throws {
    let endpoint = try ControllerEndpoint(address: "127.0.0.1:9090")

    XCTAssertEqual(endpoint.baseURL.absoluteString, "http://127.0.0.1:9090")
    XCTAssertEqual(
      try endpoint.httpURL(path: "/version").absoluteString,
      "http://127.0.0.1:9090/version"
    )
    XCTAssertEqual(
      try endpoint.webSocketURL(
        path: "/connections",
        queryItems: [URLQueryItem(name: "interval", value: "500")]
      ).absoluteString,
      "ws://127.0.0.1:9090/connections?interval=500"
    )
  }

  func testAcceptsIPv6LoopbackAddress() throws {
    let endpoint = try ControllerEndpoint(address: "http://[::1]:9090")

    XCTAssertEqual(endpoint.baseURL.absoluteString, "http://[::1]:9090")
  }

  func testRejectsNonLoopbackAddress() {
    XCTAssertThrowsError(try ControllerEndpoint(address: "http://192.168.1.2:9090")) {
      error in
      XCTAssertEqual(error as? ControllerEndpointError, .nonLoopbackAddress)
    }
  }

  func testRejectsMissingPortAndExtraPath() {
    XCTAssertThrowsError(try ControllerEndpoint(address: "http://127.0.0.1")) { error in
      XCTAssertEqual(error as? ControllerEndpointError, .missingOrInvalidPort)
    }

    XCTAssertThrowsError(try ControllerEndpoint(address: "http://127.0.0.1:9090/api")) {
      error in
      XCTAssertEqual(error as? ControllerEndpointError, .unsupportedPath)
    }
  }
}
