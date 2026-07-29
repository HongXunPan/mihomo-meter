import XCTest

@testable import MihomoMeter

final class MihomoControllerModelsTests: XCTestCase {
  private let decoder = JSONDecoder()

  func testDecodesVersionFixture() throws {
    let response = try decoder.decode(
      MihomoVersionResponse.self,
      from: FixtureLoader.data(named: "version")
    )

    XCTAssertTrue(response.meta)
    XCTAssertEqual(response.version, "v1.19.0")
  }

  func testDecodesProxyCatalogFixture() throws {
    let response = try decoder.decode(
      MihomoProxiesResponse.self,
      from: FixtureLoader.data(named: "proxies")
    )

    XCTAssertEqual(response.proxies["DIRECT"]?.type, "Direct")
    XCTAssertEqual(response.proxies["Synthetic Proxy"]?.type, "Vmess")
    XCTAssertEqual(response.proxies["Synthetic Group"]?.now, "Synthetic Proxy")
  }

  func testDecodesRuntimeConfiguration() throws {
    let data = Data(
      """
      {
        "mode": "rule",
        "allow-lan": false,
        "ipv6": true,
        "mixed-port": 7890,
        "port": 7891,
        "socks-port": 7892,
        "global-ua": "mihomo-test-agent",
        "tun": {
          "enable": true,
          "stack": "system",
          "auto-route": true
        }
      }
      """.utf8
    )

    let response = try decoder.decode(
      MihomoRuntimeConfigurationResponse.self,
      from: data
    )
    let configuration = response.runtimeConfiguration

    XCTAssertEqual(configuration.mode, "rule")
    XCTAssertEqual(configuration.allowsLAN, false)
    XCTAssertEqual(configuration.isIPv6Enabled, true)
    XCTAssertEqual(configuration.mixedPort, 7_890)
    XCTAssertEqual(configuration.httpPort, 7_891)
    XCTAssertEqual(configuration.socksPort, 7_892)
    XCTAssertEqual(configuration.globalUserAgent, "mihomo-test-agent")
    XCTAssertEqual(configuration.externalResourceUserAgent.value, "mihomo-test-agent")
    XCTAssertEqual(
      configuration.externalResourceUserAgent.source,
      .mihomoConfiguration
    )
    XCTAssertEqual(configuration.tun?.isEnabled, true)
    XCTAssertEqual(configuration.tun?.stack, "system")
    XCTAssertEqual(configuration.tun?.automaticallyRoutesTraffic, true)
  }

  func testUsesMihomoDefaultUserAgentWhenConfigurationValueIsUnsafe() {
    let configuration = MihomoRuntimeConfiguration(
      mode: nil,
      tun: nil,
      isIPv6Enabled: nil,
      allowsLAN: nil,
      mixedPort: 7_890,
      globalUserAgent: "unsafe\r\nvalue"
    )

    XCTAssertEqual(configuration.externalResourceUserAgent, .mihomoDefault)
  }

  func testDecodesConnectionFixturesWithLeafFirstChains() throws {
    let initial = try decoder.decode(
      MihomoConnectionsSnapshot.self,
      from: FixtureLoader.data(named: "connections-initial")
    )
    let next = try decoder.decode(
      MihomoConnectionsSnapshot.self,
      from: FixtureLoader.data(named: "connections-next")
    )

    XCTAssertEqual(initial.connections.count, 2)
    XCTAssertEqual(
      initial.connections.last?.chains,
      ["Synthetic Proxy", "Synthetic Group"]
    )
    XCTAssertEqual(initial.trafficSnapshot.connections.last?.rule, "DOMAIN")
    XCTAssertGreaterThan(next.downloadTotal, initial.downloadTotal)
    XCTAssertGreaterThan(next.uploadTotal, initial.uploadTotal)
  }
}
