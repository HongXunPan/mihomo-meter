import XCTest

@testable import MihomoMeter

final class TrafficRateTests: XCTestCase {
  func testZeroRateHasNoTraffic() {
    XCTAssertEqual(TrafficRate.zero.uploadBytesPerSecond, 0)
    XCTAssertEqual(TrafficRate.zero.downloadBytesPerSecond, 0)
  }

  func testFormatterUsesDecimalRateUnits() {
    XCTAssertEqual(TrafficRateFormatter.string(from: 0), "0 B/s")
    XCTAssertEqual(TrafficRateFormatter.string(from: 1_500), "1.50 KB/s")
    XCTAssertEqual(TrafficRateFormatter.string(from: 10_000), "10.0 KB/s")
  }

  func testStatusTitleKeepsDownloadBeforeUpload() {
    let rate = TrafficRate(
      uploadBytesPerSecond: 1_000,
      downloadBytesPerSecond: 2_000
    )

    XCTAssertEqual(
      TrafficRateFormatter.statusTitle(for: rate),
      "P ↓ 2.00 KB/s  ↑ 1.00 KB/s"
    )
  }
}
