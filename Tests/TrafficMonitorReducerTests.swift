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
    XCTAssertNil(state.mihomoVersion)
  }

  func testMeasurementPublishesWindowAndActiveProxyLeaves() {
    let raw = makeRates(download: 800, upload: 300)
    let smoothed = makeRates(download: 600, upload: 200)
    let result = TrafficMeasurementResult(
      activeProxyLeaves: ["Synthetic Proxy"],
      requiresCatalogRefresh: false,
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
    XCTAssertEqual(state.mihomoVersion, "v-test")
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
      mihomoVersion: "v-test",
      message: "正在读取实时连接流量。"
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
