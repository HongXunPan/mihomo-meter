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
    let result = TrafficMeasurementResult(
      activeProxyLeaves: ["Synthetic Proxy"],
      activeRuleTypes: ["DOMAIN", "RULE-SET"],
      requiresCatalogRefresh: false,
      ledgerObservation: TrafficLedgerObservation(
        observedAt: Date(timeIntervalSince1970: 1_700_000_000),
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
      activeProxyLeaves: ["Synthetic Proxy"],
      activeRuleTypes: ["DOMAIN"],
      runtimeConfiguration: makeRuntimeConfiguration(),
      mihomoVersion: "v-test",
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
