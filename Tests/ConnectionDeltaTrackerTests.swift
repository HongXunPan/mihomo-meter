import XCTest

@testable import MihomoMeter

final class ConnectionDeltaTrackerTests: XCTestCase {
  private let classifier = ProxyClassifier(
    catalog: ProxyCatalog(
      typesByName: [
        "DIRECT": "Direct",
        "Synthetic Proxy": "Vmess",
      ]
    )
  )

  func testUsesFirstSnapshotAsBaselineThenCalculatesClassifiedAndUnknownDeltas() {
    let initial = snapshot(
      kernelUpload: 1_000,
      kernelDownload: 2_000,
      connections: [
        connection("direct", upload: 100, download: 300, chain: "DIRECT"),
        connection("proxy", upload: 200, download: 500, chain: "Synthetic Proxy"),
      ]
    )
    let next = snapshot(
      kernelUpload: 1_400,
      kernelDownload: 2_900,
      connections: [
        connection("direct", upload: 180, download: 520, chain: "DIRECT"),
        connection("proxy", upload: 420, download: 1_080, chain: "Synthetic Proxy"),
      ]
    )
    var tracker = ConnectionDeltaTracker()

    XCTAssertEqual(
      tracker.consume(initial, classifier: classifier),
      .baselineEstablished
    )

    guard case .delta(let batch) = tracker.consume(next, classifier: classifier) else {
      return XCTFail("第二份快照应产生增量")
    }

    let report = batch.traffic
    XCTAssertEqual(report.categories.direct, TrafficBytes(upload: 80, download: 220))
    XCTAssertEqual(report.categories.proxy, TrafficBytes(upload: 220, download: 580))
    XCTAssertEqual(report.categories.unknown, TrafficBytes(upload: 100, download: 100))
    XCTAssertEqual(report.coverage, 1_100.0 / 1_300.0, accuracy: 0.000_001)
    XCTAssertEqual(batch.connections.count, 2)
    XCTAssertEqual(
      batch.connections.first { $0.id == "proxy" }?.bytes,
      TrafficBytes(upload: 220, download: 580)
    )
  }

  func testCountsNewConnectionFromZeroAfterBaseline() {
    var tracker = ConnectionDeltaTracker()
    _ = tracker.consume(
      snapshot(kernelUpload: 100, kernelDownload: 100, connections: []),
      classifier: classifier
    )

    let result = tracker.consume(
      snapshot(
        kernelUpload: 130,
        kernelDownload: 150,
        connections: [
          connection("new", upload: 30, download: 50, chain: "Synthetic Proxy")
        ]
      ),
      classifier: classifier
    )

    guard case .delta(let batch) = result else {
      return XCTFail("新连接应从零计算增量")
    }
    let report = batch.traffic
    XCTAssertEqual(report.categories.proxy, TrafficBytes(upload: 30, download: 50))
    XCTAssertEqual(report.categories.unknown, .zero)
  }

  func testRebuildsBaselineWhenKernelCountersRollBack() {
    var tracker = ConnectionDeltaTracker()
    _ = tracker.consume(
      snapshot(kernelUpload: 100, kernelDownload: 200, connections: []),
      classifier: classifier
    )

    XCTAssertEqual(
      tracker.consume(
        snapshot(kernelUpload: 10, kernelDownload: 20, connections: []),
        classifier: classifier
      ),
      .countersReset
    )
  }

  private func snapshot(
    kernelUpload: UInt64,
    kernelDownload: UInt64,
    connections: [ConnectionTrafficSample]
  ) -> ConnectionTrafficSnapshot {
    ConnectionTrafficSnapshot(
      kernelTotal: TrafficBytes(upload: kernelUpload, download: kernelDownload),
      connections: connections
    )
  }

  private func connection(
    _ id: String,
    upload: UInt64,
    download: UInt64,
    chain: String
  ) -> ConnectionTrafficSample {
    ConnectionTrafficSample(
      id: id,
      bytes: TrafficBytes(upload: upload, download: download),
      chains: [chain]
    )
  }
}
