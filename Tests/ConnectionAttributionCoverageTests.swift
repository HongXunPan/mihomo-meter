import XCTest

@testable import MihomoMeter

final class ConnectionAttributionCoverageTests: XCTestCase {
  func testCountsEachConnectionOnceAndUpgradesAvailability() {
    var tracker = ConnectionAttributionCoverageTracker()

    XCTAssertEqual(
      tracker.consume([
        connection("first", hostname: true, application: false),
        connection("second", hostname: false, application: true),
      ]),
      ConnectionAttributionCoverage(
        proxyConnectionCount: 2,
        hostnameIdentifiedCount: 1,
        applicationIdentifiedCount: 1,
        fullyIdentifiedCount: 0
      )
    )

    XCTAssertEqual(
      tracker.consume([
        connection("first", hostname: false, application: true)
      ]),
      ConnectionAttributionCoverage(
        proxyConnectionCount: 2,
        hostnameIdentifiedCount: 1,
        applicationIdentifiedCount: 2,
        fullyIdentifiedCount: 1
      )
    )
  }

  func testResetRemovesInMemoryConnectionIdentifiers() {
    var tracker = ConnectionAttributionCoverageTracker()
    _ = tracker.consume([connection("connection", hostname: true, application: true)])

    tracker.reset()

    XCTAssertEqual(tracker.consume([]), .empty)
  }

  private func connection(
    _ id: String,
    hostname: Bool,
    application: Bool
  ) -> ConnectionTrafficSample {
    ConnectionTrafficSample(
      id: id,
      bytes: .zero,
      chains: ["Proxy"],
      metadata: ConnectionMetadata(
        hostname: hostname ? "example.com" : nil,
        applicationName: application ? "Example" : nil
      )
    )
  }
}
