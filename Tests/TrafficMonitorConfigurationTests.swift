import Foundation
import Security
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

final class ApplicationRuntimeEnvironmentTests: XCTestCase {
  func testExplicitTestModeDisablesProductionServices() {
    let environment = ApplicationRuntimeEnvironment(
      variables: ["MIHOMO_METER_TEST_MODE": "1"]
    )

    XCTAssertFalse(environment.shouldStartProductionServices)
  }

  func testXCTestMarkerDisablesProductionServices() {
    let environment = ApplicationRuntimeEnvironment(
      variables: ["XCTestConfigurationFilePath": "synthetic-test-configuration"]
    )

    XCTAssertFalse(environment.shouldStartProductionServices)
  }

  func testRegularLaunchStartsProductionServices() {
    let environment = ApplicationRuntimeEnvironment(variables: [:])

    XCTAssertTrue(environment.shouldStartProductionServices)
  }

  func testCurrentTestHostDoesNotStartProductionServices() {
    XCTAssertFalse(
      ApplicationRuntimeEnvironment.current.shouldStartProductionServices
    )
  }
}

final class KeychainSecretStoreTests: XCTestCase {
  func testBaseQueryTargetsFileBasedLoginKeychain() {
    let query = KeychainSecretStore.makeBaseQuery(
      service: "com.example.MihomoMeter.controller",
      account: "synthetic-account"
    )

    XCTAssertEqual(
      query[kSecUseDataProtectionKeychain as String] as? Bool,
      false
    )
    XCTAssertNil(query[kSecAttrSynchronizable as String])
    XCTAssertNil(query[kSecAttrAccessGroup as String])
  }

  func testAppEntitlementsDoNotRequireProvisionedKeychainAccessGroup() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let entitlementsURL =
      repositoryRoot
      .appendingPathComponent("MihomoMeter.entitlements")
    let data = try Data(contentsOf: entitlementsURL)
    let propertyList = try XCTUnwrap(
      PropertyListSerialization.propertyList(
        from: data,
        format: nil
      ) as? [String: Any]
    )

    XCTAssertNil(propertyList["keychain-access-groups"])
    XCTAssertEqual(propertyList["com.apple.security.app-sandbox"] as? Bool, true)
    XCTAssertEqual(propertyList["com.apple.security.network.client"] as? Bool, true)
  }
}
