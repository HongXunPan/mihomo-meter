import XCTest

@testable import MihomoMeter

final class ConnectionAnalyticsRecordingCoverageTests: XCTestCase {
  func testRateIsUnavailableWhenCoreHasNoTraffic() {
    let coverage = ConnectionAnalyticsRecordingCoverage(
      attributed: .zero,
      coreProxy: .zero
    )

    XCTAssertNil(coverage.rate)
  }
}
