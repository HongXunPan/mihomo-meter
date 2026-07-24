import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class TrafficMonitorConfigurationTests: TrafficMonitorTestCase {
  func testAuthenticationFailureStopsWithoutStartingCollector() async throws {
    let collector = MonitorTestCollector()
    let (userDefaults, suiteName) = makeUserDefaults()
    defer {
      userDefaults.removePersistentDomain(forName: suiteName)
    }
    let monitor = TrafficMonitor(
      client: MonitorTestClient(error: MihomoControllerError.authenticationFailed),
      collector: collector,
      secretStore: MonitorTestSecretStore(),
      userDefaults: userDefaults
    )
    monitor.address = "127.0.0.1:9090"
    monitor.secret = "synthetic-secret"

    monitor.connect()
    try await waitUntil { monitor.connectionState == .authenticationFailed }

    let collectionCount = await collector.collectionCount
    XCTAssertEqual(collectionCount, 0)
    XCTAssertEqual(monitor.rates, .zero)
  }

  func testSuccessfulValidationSavesConfigurationAndConsumesSnapshot() async throws {
    let collector = MonitorTestCollector(
      snapshot: MihomoConnectionsSnapshot(
        downloadTotal: 2_000,
        uploadTotal: 1_000,
        connections: []
      )
    )
    let secretStore = MonitorTestSecretStore()
    let (userDefaults, suiteName) = makeUserDefaults()
    defer {
      userDefaults.removePersistentDomain(forName: suiteName)
    }
    let monitor = TrafficMonitor(
      client: MonitorTestClient(),
      collector: collector,
      secretStore: secretStore,
      userDefaults: userDefaults
    )
    monitor.address = "127.0.0.1:9090"
    monitor.secret = "synthetic-secret"

    monitor.connect()
    try await waitUntil { monitor.connectionState == .connected }

    let savedSecret = await secretStore.loadSecret(reason: .applicationStartup)
    let saveCount = await secretStore.saveCount
    XCTAssertEqual(monitor.mihomoVersion, "v-test")
    XCTAssertEqual(savedSecret, "synthetic-secret")
    XCTAssertEqual(saveCount, 1)
    XCTAssertEqual(
      userDefaults.string(forKey: "controllerAddress"),
      "http://127.0.0.1:9090"
    )

    monitor.disconnect()
  }

  func testStartupValidationDoesNotRewriteLoadedSecret() async throws {
    let secretStore = MonitorTestSecretStore(secret: "synthetic-secret")
    let (userDefaults, suiteName) = makeUserDefaults()
    defer {
      userDefaults.removePersistentDomain(forName: suiteName)
    }
    userDefaults.set("http://127.0.0.1:9090", forKey: "controllerAddress")
    let monitor = TrafficMonitor(
      client: MonitorTestClient(),
      collector: MonitorTestCollector(
        snapshot: MihomoConnectionsSnapshot(
          downloadTotal: 2_000,
          uploadTotal: 1_000,
          connections: []
        )
      ),
      secretStore: secretStore,
      userDefaults: userDefaults
    )

    monitor.start()
    try await waitUntil {
      monitor.connectionState == .connected
    }

    let saveCount = await secretStore.saveCount
    XCTAssertEqual(saveCount, 0)
    monitor.disconnect()
  }
}
