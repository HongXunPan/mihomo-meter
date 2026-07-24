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

  func testCompactFormatterRemovesSpacesAndShortensUnits() {
    XCTAssertEqual(TrafficRateFormatter.compactString(from: 0), "0B/s")
    XCTAssertEqual(TrafficRateFormatter.compactString(from: 1_500), "1.50K/s")
    XCTAssertEqual(TrafficRateFormatter.compactString(from: 10_000), "10.0K/s")
  }

  func testStatusTextKeepsDownloadBeforeUpload() {
    let rate = TrafficRate(
      uploadBytesPerSecond: 1_000,
      downloadBytesPerSecond: 2_000
    )

    let statusText = TrafficRateFormatter.statusText(for: rate)

    XCTAssertEqual(statusText.download, "↓2.00K/s")
    XCTAssertEqual(statusText.upload, "↑1.00K/s")
  }

  func testCoveragePercentageClampsInvalidRange() {
    XCTAssertEqual(TrafficRateFormatter.percentage(from: nil), "—")
    XCTAssertEqual(TrafficRateFormatter.percentage(from: 0.9998), "99.98%")
    XCTAssertEqual(TrafficRateFormatter.percentage(from: 2), "100.00%")
  }

  func testCoveragePolicyMarksValuesBelowNinetyFivePercentAsLow() {
    XCTAssertEqual(TrafficCoveragePolicy.quality(for: nil), .unavailable)
    XCTAssertEqual(TrafficCoveragePolicy.quality(for: 0.9499), .low)
    XCTAssertEqual(TrafficCoveragePolicy.quality(for: 0.95), .reliable)
  }
}
