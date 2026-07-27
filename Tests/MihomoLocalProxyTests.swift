import Foundation
import XCTest

@testable import MihomoMeter

final class MihomoLocalProxyTests: XCTestCase {
  private let endpoint = try! ControllerEndpoint(address: "127.0.0.1:9090")

  func testPrefersMixedThenHTTPThenSocksProxyPort() {
    assertProxy(proxy(mixed: 7890, http: 7891, socks: 7892), port: 7890, kind: .mixed)
    assertProxy(proxy(mixed: 0, http: 7891, socks: 7892), port: 7891, kind: .http)
    assertProxy(proxy(mixed: nil, http: nil, socks: 7892), port: 7892, kind: .socks)
  }

  func testRejectsMissingOrInvalidProxyPorts() {
    XCTAssertNil(proxy(mixed: nil, http: nil, socks: nil))
    XCTAssertNil(proxy(mixed: 0, http: 70_000, socks: -1))
  }

  private func proxy(mixed: Int?, http: Int?, socks: Int?) -> MihomoLocalProxy? {
    MihomoLocalProxy(
      endpoint: endpoint,
      runtimeConfiguration: MihomoRuntimeConfiguration(
        mode: nil,
        tun: nil,
        isIPv6Enabled: nil,
        allowsLAN: nil,
        mixedPort: mixed,
        httpPort: http,
        socksPort: socks
      )
    )
  }

  private func assertProxy(
    _ proxy: MihomoLocalProxy?,
    port: Int,
    kind: MihomoLocalProxyKind,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(proxy?.host, "127.0.0.1", file: file, line: line)
    XCTAssertEqual(proxy?.port, port, file: file, line: line)
    XCTAssertEqual(proxy?.kind, kind, file: file, line: line)
  }
}
