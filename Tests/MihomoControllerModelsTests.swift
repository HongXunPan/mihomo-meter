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
        "find-process-mode": "strict",
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
    XCTAssertEqual(configuration.processMatchingMode, .strict)
    XCTAssertEqual(configuration.externalResourceUserAgent.value, "mihomo-test-agent")
    XCTAssertEqual(
      configuration.externalResourceUserAgent.source,
      .mihomoConfiguration
    )
    XCTAssertEqual(configuration.tun?.isEnabled, true)
    XCTAssertEqual(configuration.tun?.stack, "system")
    XCTAssertEqual(configuration.tun?.automaticallyRoutesTraffic, true)
  }

  func testUnknownProcessMatchingModeRemainsUnavailable() throws {
    let response = try decoder.decode(
      MihomoRuntimeConfigurationResponse.self,
      from: Data("{\"find-process-mode\":\"future-mode\"}".utf8)
    )

    XCTAssertNil(response.runtimeConfiguration.processMatchingMode)
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

  func testMapsSanitizedMetadataAndConnectionStartTime() throws {
    let response = try decoder.decode(
      MihomoConnectionsSnapshot.self,
      from: Data(
        """
        {"downloadTotal":0,"uploadTotal":0,"connections":[{
          "id":"synthetic","upload":0,"download":0,"chains":["Synthetic Proxy"],
          "start":"2026-07-30T08:00:00.123Z",
          "metadata":{"host":"synthetic-host","processPath":"/Synthetic/App"}
        }]}
        """.utf8
      )
    )

    XCTAssertEqual(
      response.trafficSnapshot.connections.first?.metadata,
      ConnectionMetadata(hostname: "synthetic-host", applicationName: "App")
    )
    XCTAssertNotNil(response.trafficSnapshot.connections.first?.startedAt)
  }

  func testRejectsEmptyAndOversizedMetadataValuesForCoverage() throws {
    let oversized = String(repeating: "x", count: 2_049)
    let data = Data(
      """
      {"downloadTotal":0,"uploadTotal":0,"connections":[{
        "id":"synthetic","upload":0,"download":0,"chains":["Synthetic Proxy"],
        "metadata":{"host":" ","sniffHost":"\(oversized)","process":"\\n","processPath":"/"}
      }]}
      """.utf8
    )

    let response = try decoder.decode(MihomoConnectionsSnapshot.self, from: data)

    XCTAssertEqual(
      response.trafficSnapshot.connections.first?.metadataAvailability,
      .unavailable
    )
  }

  func testMalformedOptionalMetadataDoesNotBreakTrafficDecoding() throws {
    let data = Data(
      """
      {"downloadTotal":1,"uploadTotal":2,"connections":[{
        "id":"synthetic","upload":2,"download":1,"chains":["Synthetic Proxy"],
        "metadata":{"host":42,"processPath":["unexpected"]}
      }]}
      """.utf8
    )

    let response = try decoder.decode(MihomoConnectionsSnapshot.self, from: data)

    XCTAssertEqual(response.trafficSnapshot.kernelTotal, TrafficBytes(upload: 2, download: 1))
    XCTAssertEqual(
      response.trafficSnapshot.connections.first?.metadataAvailability,
      .unavailable
    )
  }

  func testDoesNotUseIPAddressAsHostnameFallback() throws {
    let data = Data(
      """
      {"downloadTotal":0,"uploadTotal":0,"connections":[{
        "id":"synthetic","upload":0,"download":0,"chains":["Synthetic Proxy"],
        "metadata":{"host":"203.0.113.1","destinationIP":"203.0.113.1"}
      }]}
      """.utf8
    )

    let response = try decoder.decode(MihomoConnectionsSnapshot.self, from: data)

    XCTAssertNil(response.trafficSnapshot.connections.first?.metadata.hostname)
  }

  func testNeverPassesFullProcessPathIntoDomainMetadata() throws {
    let data = Data(
      """
      {"downloadTotal":0,"uploadTotal":0,"connections":[{
        "id":"synthetic","upload":0,"download":0,"chains":["Synthetic Proxy"],
        "metadata":{"process":"/Applications/Synthetic.app/Contents/MacOS/Synthetic"}
      }]}
      """.utf8
    )

    let response = try decoder.decode(MihomoConnectionsSnapshot.self, from: data)

    XCTAssertEqual(
      response.trafficSnapshot.connections.first?.metadata.applicationName,
      "Synthetic"
    )
  }

  func testUsesOutermostApplicationBundleFromProcessPath() throws {
    let data = Data(
      """
      {"downloadTotal":0,"uploadTotal":0,"connections":[{
        "id":"synthetic","upload":0,"download":0,"chains":["Synthetic Proxy"],
        "metadata":{
          "process":"Google Chrome Helper",
          "processPath":"/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper"
        }
      }]}
      """.utf8
    )

    let response = try decoder.decode(MihomoConnectionsSnapshot.self, from: data)
    let applicationName = response.trafficSnapshot.connections.first?.metadata.applicationName

    XCTAssertEqual(applicationName, "Google Chrome")
    XCTAssertFalse(try XCTUnwrap(applicationName).contains("/"))
  }

  func testUsesApplicationBundleFromWindowsStyleProcessPath() throws {
    let data = Data(
      """
      {"downloadTotal":0,"uploadTotal":0,"connections":[{
        "id":"synthetic","upload":0,"download":0,"chains":["Synthetic Proxy"],
        "metadata":{
          "process":"com.synthetic.backend",
          "processPath":"C:\\\\Apps\\\\Synthetic.app\\\\Contents\\\\com.synthetic.backend"
        }
      }]}
      """.utf8
    )

    let response = try decoder.decode(MihomoConnectionsSnapshot.self, from: data)

    XCTAssertEqual(
      response.trafficSnapshot.connections.first?.metadata.applicationName,
      "Synthetic"
    )
  }
}
