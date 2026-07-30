import XCTest

@testable import MihomoMeter

final class ConnectionAnalyticsTrendTests: XCTestCase {
  func testSummaryUsesActiveDaysAndMostRecentPeakTie() {
    let trend = ConnectionAnalyticsTrend(
      points: [
        point("2026-07-27", upload: 10, download: 20),
        point("2026-07-28", upload: 0, download: 0),
        point("2026-07-29", upload: 15, download: 15),
        point("2026-07-30", upload: 4, download: 6),
      ]
    )

    XCTAssertEqual(trend.totalBytes, TrafficBytes(upload: 29, download: 41))
    XCTAssertEqual(trend.activeDayCount, 3)
    XCTAssertEqual(trend.activeDailyAverageBytes, 23)
    XCTAssertEqual(trend.peakPoint?.localDay, "2026-07-29")
    XCTAssertEqual(trend.defaultSelectedLocalDay, "2026-07-30")
  }

  func testEmptyTrendHasNoPeakOrDefaultSelection() {
    let trend = ConnectionAnalyticsTrend(
      points: [point("2026-07-30", upload: 0, download: 0)]
    )

    XCTAssertEqual(trend.activeDayCount, 0)
    XCTAssertEqual(trend.activeDailyAverageBytes, 0)
    XCTAssertNil(trend.peakPoint)
    XCTAssertNil(trend.defaultSelectedLocalDay)
  }

  private func point(
    _ localDay: String,
    upload: UInt64,
    download: UInt64
  ) -> ConnectionAnalyticsTrendPoint {
    ConnectionAnalyticsTrendPoint(
      localDay: localDay,
      bytes: TrafficBytes(upload: upload, download: download)
    )
  }
}
