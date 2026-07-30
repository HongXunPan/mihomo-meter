import XCTest

@testable import MihomoMeter

final class ProxyConnectionRateAggregatorTests: XCTestCase {
  func testUsesOneSecondWindowAndTwoWindowSmoothing() {
    var aggregator = ProxyConnectionRateAggregator()
    aggregator.establishBaseline([connection(id: "first", upload: 100, download: 200)])

    let firstWindow = aggregator.consume(
      activeConnections: [connection(id: "first", upload: 300, download: 600)],
      deltas: [delta(id: "first", upload: 200, download: 400)],
      elapsedSeconds: 1
    )
    XCTAssertEqual(
      firstWindow.first?.rate,
      TrafficRate(uploadBytesPerSecond: 200, downloadBytesPerSecond: 400)
    )

    let secondWindow = aggregator.consume(
      activeConnections: [connection(id: "first", upload: 700, download: 1_400)],
      deltas: [delta(id: "first", upload: 400, download: 800)],
      elapsedSeconds: 1
    )
    XCTAssertEqual(
      secondWindow.first?.rate,
      TrafficRate(uploadBytesPerSecond: 300, downloadBytesPerSecond: 600)
    )
  }

  func testRemovesMissingConnectionImmediately() {
    var aggregator = ProxyConnectionRateAggregator()
    aggregator.establishBaseline([connection(id: "first", upload: 100, download: 200)])

    let current = aggregator.consume(
      activeConnections: [],
      deltas: [],
      elapsedSeconds: 0.5
    )

    XCTAssertTrue(current.isEmpty)
  }

  func testResetClearsLiveConnectionsAndSmoothingState() {
    var aggregator = ProxyConnectionRateAggregator()
    aggregator.establishBaseline([connection(id: "first", upload: 100, download: 200)])
    _ = aggregator.consume(
      activeConnections: [connection(id: "first", upload: 200, download: 400)],
      deltas: [delta(id: "first", upload: 100, download: 200)],
      elapsedSeconds: 1
    )

    aggregator.reset()

    XCTAssertTrue(aggregator.liveConnections.isEmpty)
  }

  private func connection(
    id: String,
    upload: UInt64,
    download: UInt64
  ) -> ConnectionTrafficSample {
    ConnectionTrafficSample(
      id: id,
      bytes: TrafficBytes(upload: upload, download: download),
      chains: ["Proxy"],
      metadata: ConnectionMetadata(hostname: "example.com", applicationName: "Example")
    )
  }

  private func delta(
    id: String,
    upload: UInt64,
    download: UInt64
  ) -> ConnectionTrafficDelta {
    ConnectionTrafficDelta(
      id: id,
      category: .proxy,
      bytes: TrafficBytes(upload: upload, download: download),
      cumulativeBytes: TrafficBytes(upload: upload, download: download),
      metadata: ConnectionMetadata(hostname: "example.com", applicationName: "Example"),
      startedAt: nil
    )
  }
}
