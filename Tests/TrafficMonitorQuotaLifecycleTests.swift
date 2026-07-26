import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class TrafficMonitorQuotaLifecycleTests: TrafficMonitorTestCase {
  func testValidationStartsQuotaObservationAndDisconnectStopsIt() async throws {
    let quotaLifecycle = MonitorTestQuotaLifecycle()
    let (userDefaults, suiteName) = makeUserDefaults()
    defer {
      userDefaults.removePersistentDomain(forName: suiteName)
    }
    let monitor = TrafficMonitor(
      client: MonitorTestClient(),
      collector: MonitorTestCollector(
        snapshot: MihomoConnectionsSnapshot(
          downloadTotal: 2_000,
          uploadTotal: 1_000,
          connections: []
        )
      ),
      secretStore: MonitorTestSecretStore(),
      runtimeQuotaLifecycle: quotaLifecycle,
      userDefaults: userDefaults
    )
    monitor.address = "127.0.0.1:9090"
    monitor.secret = "synthetic-secret"

    monitor.connect()
    try await waitUntil {
      quotaLifecycle.validationCount == 1
    }

    XCTAssertEqual(
      quotaLifecycle.lastEndpoint,
      try ControllerEndpoint(address: "127.0.0.1:9090")
    )
    XCTAssertEqual(quotaLifecycle.lastSecret, "synthetic-secret")
    let unavailableCountBeforeDisconnect = quotaLifecycle.unavailableCount

    monitor.disconnect()
    try await waitUntil {
      quotaLifecycle.unavailableCount > unavailableCountBeforeDisconnect
    }
  }
}

@MainActor
private final class MonitorTestQuotaLifecycle: RuntimeQuotaTrackingLifecycle {
  private(set) var validationCount = 0
  private(set) var unavailableCount = 0
  private(set) var lastEndpoint: ControllerEndpoint?
  private(set) var lastSecret: String?

  func controllerValidated(endpoint: ControllerEndpoint, secret: String) {
    validationCount += 1
    lastEndpoint = endpoint
    lastSecret = secret
  }

  func controllerUnavailable() {
    unavailableCount += 1
  }
}
