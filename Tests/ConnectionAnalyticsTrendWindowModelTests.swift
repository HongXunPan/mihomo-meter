import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class ConnectionAnalyticsTrendWindowModelTests: XCTestCase {
  func testRapidTargetSwitchDoesNotAllowOldResultToOverwriteNewResult() async throws {
    let model = ConnectionAnalyticsTrendWindowModel { query in
      if query.applicationName == "旧应用" {
        await withCheckedContinuation { continuation in
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            continuation.resume()
          }
        }
        return self.trend(day: "2026-07-29", total: 10)
      }
      return self.trend(day: "2026-07-30", total: 20)
    }
    let oldTarget = ConnectionAnalyticsPresentation.applicationTrendTarget(
      applicationName: "旧应用",
      selectedHostname: nil
    )
    let newTarget = ConnectionAnalyticsPresentation.applicationTrendTarget(
      applicationName: "新应用",
      selectedHostname: nil
    )

    model.show(target: oldTarget)
    await Task.yield()
    model.show(target: newTarget)
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertEqual(model.target, newTarget)
    guard case .loaded(let loadedTrend) = model.state else {
      return XCTFail("新对象趋势未完成加载")
    }
    XCTAssertEqual(loadedTrend.totalBytes.total, 20)
  }

  func testResetClearsTargetAndLoadedData() async {
    let model = ConnectionAnalyticsTrendWindowModel { _ in
      self.trend(day: "2026-07-30", total: 20)
    }
    let target = ConnectionAnalyticsPresentation.hostnameTrendTarget(
      hostname: "example.com",
      selectedApplication: nil
    )
    model.show(target: target)
    await Task.yield()

    model.reset()

    XCTAssertNil(model.target)
    XCTAssertEqual(model.state, .idle)
  }

  private func trend(day: String, total: UInt64) -> ConnectionAnalyticsTrend {
    ConnectionAnalyticsTrend(
      points: [
        ConnectionAnalyticsTrendPoint(
          localDay: day,
          bytes: TrafficBytes(upload: total, download: 0)
        )
      ]
    )
  }
}
