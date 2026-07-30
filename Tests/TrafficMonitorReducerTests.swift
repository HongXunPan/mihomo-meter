import Foundation
import XCTest

@testable import MihomoMeter

final class TrafficMonitorReducerTests: XCTestCase {
  func testValidatingClearsPreviousLiveStateAndVersion() {
    let previous = makePopulatedState()

    let state = TrafficMonitorReducer.reduce(previous, event: .validating)

    XCTAssertEqual(state.connectionState, .connecting)
    XCTAssertEqual(state.rates, .zero)
    XCTAssertEqual(state.rawRates, .zero)
    XCTAssertNil(state.coverage)
    XCTAssertEqual(state.activeProxyLeaves, [])
    XCTAssertEqual(state.activeRuleTypes, [])
    XCTAssertNil(state.mihomoVersion)
    XCTAssertNil(state.runtimeConfiguration)
  }

  func testValidatedPublishesRuntimeConfiguration() {
    let runtimeConfiguration = makeRuntimeConfiguration()

    let state = TrafficMonitorReducer.reduce(
      TrafficMonitorState(),
      event: .validated(
        address: "http://127.0.0.1:9090",
        version: "v-test",
        runtimeConfiguration: runtimeConfiguration
      )
    )

    XCTAssertEqual(state.mihomoVersion, "v-test")
    XCTAssertEqual(state.runtimeConfiguration, runtimeConfiguration)
  }

  func testMeasurementPublishesWindowProxyLeavesAndRuleTypes() {
    let raw = makeRates(download: 800, upload: 300)
    let smoothed = makeRates(download: 600, upload: 200)
    let observedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let result = TrafficMeasurementResult(
      activeProxyLeaves: ["Synthetic Proxy"],
      activeRuleTypes: ["DOMAIN", "RULE-SET"],
      attributionCoverage: ConnectionAttributionCoverage(
        proxyConnectionCount: 3,
        hostnameIdentifiedCount: 2,
        applicationIdentifiedCount: 1,
        fullyIdentifiedCount: 1
      ),
      liveProxyConnections: [
        LiveProxyConnection(
          id: "connection",
          metadata: ConnectionMetadata(hostname: "example.com", applicationName: "Example"),
          rate: TrafficRate(uploadBytesPerSecond: 100, downloadBytesPerSecond: 200),
          cumulativeBytes: TrafficBytes(upload: 300, download: 400),
          startedAt: nil
        )
      ],
      connectionAttributionDeltas: [],
      requiresCatalogRefresh: false,
      ledgerObservation: TrafficLedgerObservation(
        observedAt: observedAt,
        kernelTotal: .zero,
        transition: .baselineEstablished
      ),
      rateWindow: TrafficRateWindow(
        raw: raw,
        smoothed: smoothed,
        coverage: 0.98
      )
    )

    let state = TrafficMonitorReducer.reduce(
      TrafficMonitorState(),
      event: .measurement(result)
    )

    XCTAssertEqual(state.connectionState, .connected)
    XCTAssertEqual(state.rawRates, raw)
    XCTAssertEqual(state.rates, smoothed)
    XCTAssertEqual(state.coverage, 0.98)
    XCTAssertEqual(state.activeProxyLeaves, ["Synthetic Proxy"])
    XCTAssertEqual(state.activeRuleTypes, ["DOMAIN", "RULE-SET"])
    XCTAssertEqual(state.attributionCoverage.proxyConnectionCount, 3)
    XCTAssertEqual(state.liveProxyConnections.count, 1)
    XCTAssertEqual(state.lastObservedAt, observedAt)
  }

  func testDataStaleClearsLiveStateButPreservesVersion() {
    let previous = makePopulatedState()

    let state = TrafficMonitorReducer.reduce(
      previous,
      event: .dataStale(
        staleTimeoutSeconds: 2,
        reconnectAfterSeconds: 5,
        lastSnapshotAgeMilliseconds: 2_100
      )
    )

    XCTAssertEqual(state.connectionState, .stale)
    XCTAssertEqual(state.rates, .zero)
    XCTAssertEqual(state.rawRates, .zero)
    XCTAssertNil(state.coverage)
    XCTAssertEqual(state.activeProxyLeaves, [])
    XCTAssertEqual(state.activeRuleTypes, [])
    XCTAssertTrue(state.liveProxyConnections.isEmpty)
    XCTAssertNil(state.lastObservedAt)
    XCTAssertEqual(state.mihomoVersion, "v-test")
    XCTAssertEqual(state.runtimeConfiguration, makeRuntimeConfiguration())
    XCTAssertEqual(
      state.message,
      "超过 2 秒未收到实时数据；持续 5 秒将重新连接。"
    )
  }

  private func makePopulatedState() -> TrafficMonitorState {
    TrafficMonitorState(
      connectionState: .connected,
      rates: makeRates(download: 600, upload: 200),
      rawRates: makeRates(download: 800, upload: 300),
      coverage: 0.98,
      liveProxyConnections: [
        LiveProxyConnection(
          id: "connection",
          metadata: ConnectionMetadata(hostname: "example.com", applicationName: "Example"),
          rate: TrafficRate(uploadBytesPerSecond: 100, downloadBytesPerSecond: 200),
          cumulativeBytes: TrafficBytes(upload: 300, download: 400),
          startedAt: nil
        )
      ],
      activeProxyLeaves: ["Synthetic Proxy"],
      activeRuleTypes: ["DOMAIN"],
      runtimeConfiguration: makeRuntimeConfiguration(),
      mihomoVersion: "v-test",
      lastObservedAt: Date(timeIntervalSince1970: 1_700_000_000),
      message: "正在读取实时连接流量。"
    )
  }

  private func makeRuntimeConfiguration() -> MihomoRuntimeConfiguration {
    MihomoRuntimeConfiguration(
      mode: "rule",
      tun: MihomoTunRuntimeConfiguration(
        isEnabled: true,
        stack: "system",
        automaticallyRoutesTraffic: true
      ),
      isIPv6Enabled: true,
      allowsLAN: false,
      mixedPort: 7_890
    )
  }

  private func makeRates(
    download: UInt64,
    upload: UInt64
  ) -> CategorizedTrafficRates {
    CategorizedTrafficRates(
      proxy: TrafficRate(
        uploadBytesPerSecond: upload,
        downloadBytesPerSecond: download
      ),
      direct: .zero,
      reject: .zero,
      unknown: .zero
    )
  }
}
