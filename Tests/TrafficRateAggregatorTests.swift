import XCTest

@testable import MihomoMeter

final class TrafficRateAggregatorTests: XCTestCase {
  func testAggregatesHalfSecondSamplesAndSmoothsTwoCompleteWindows() {
    var aggregator = TrafficRateAggregator()

    XCTAssertNil(
      aggregator.consume(report(proxyUpload: 100, proxyDownload: 200), elapsedSeconds: 0.5)
    )
    let first = aggregator.consume(
      report(proxyUpload: 100, proxyDownload: 200),
      elapsedSeconds: 0.5
    )

    XCTAssertEqual(
      first?.raw.proxy,
      TrafficRate(uploadBytesPerSecond: 200, downloadBytesPerSecond: 400)
    )
    XCTAssertEqual(first?.smoothed.proxy, first?.raw.proxy)

    XCTAssertNil(
      aggregator.consume(report(proxyUpload: 300, proxyDownload: 500), elapsedSeconds: 0.5)
    )
    let second = aggregator.consume(
      report(proxyUpload: 300, proxyDownload: 500),
      elapsedSeconds: 0.5
    )

    XCTAssertEqual(
      second?.raw.proxy,
      TrafficRate(uploadBytesPerSecond: 600, downloadBytesPerSecond: 1_000)
    )
    XCTAssertEqual(
      second?.smoothed.proxy,
      TrafficRate(uploadBytesPerSecond: 400, downloadBytesPerSecond: 700)
    )
  }

  func testCalculatesCoverageFromWholeCompletedWindow() {
    var aggregator = TrafficRateAggregator()
    let first = TrafficDeltaReport(
      kernel: TrafficBytes(upload: 100, download: 100),
      categories: CategorizedTrafficBytes(
        proxy: TrafficBytes(upload: 50, download: 50),
        direct: .zero,
        reject: .zero,
        unknown: TrafficBytes(upload: 50, download: 50)
      )
    )
    let second = TrafficDeltaReport(
      kernel: TrafficBytes(upload: 300, download: 100),
      categories: CategorizedTrafficBytes(
        proxy: TrafficBytes(upload: 150, download: 50),
        direct: .zero,
        reject: .zero,
        unknown: TrafficBytes(upload: 150, download: 50)
      )
    )

    XCTAssertNil(aggregator.consume(first, elapsedSeconds: 0.5))
    let window = aggregator.consume(second, elapsedSeconds: 0.5)

    XCTAssertEqual(window?.coverage ?? 0, 0.5, accuracy: 0.000_001)
  }

  private func report(
    proxyUpload: UInt64,
    proxyDownload: UInt64
  ) -> TrafficDeltaReport {
    let proxy = TrafficBytes(upload: proxyUpload, download: proxyDownload)
    return TrafficDeltaReport(
      kernel: proxy,
      categories: CategorizedTrafficBytes(
        proxy: proxy,
        direct: .zero,
        reject: .zero,
        unknown: .zero
      )
    )
  }
}
