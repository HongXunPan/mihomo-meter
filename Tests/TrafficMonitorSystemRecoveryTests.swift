import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class TrafficMonitorSystemRecoveryTests: TrafficMonitorTestCase {
  func testValidatedConnectionPausesAndResumesOnceWithSystemEnvironment() async throws {
    let diagnosticLogger = MonitorTestDiagnosticLogger()
    let collector = MonitorTestCollector(
      snapshot: MihomoConnectionsSnapshot(
        downloadTotal: 2_000,
        uploadTotal: 1_000,
        connections: []
      )
    )
    let (userDefaults, suiteName) = makeUserDefaults()
    defer {
      userDefaults.removePersistentDomain(forName: suiteName)
    }
    userDefaults.set("http://127.0.0.1:9090", forKey: "controllerAddress")
    let monitor = TrafficMonitor(
      client: MonitorTestClient(),
      collector: collector,
      secretStore: MonitorTestSecretStore(secret: "synthetic-secret"),
      diagnosticLogger: diagnosticLogger,
      userDefaults: userDefaults
    )

    monitor.start()
    try await waitUntil { monitor.connectionState == .connected }
    monitor.setSystemEnvironmentAvailable(false)
    try await waitUntil { monitor.connectionState == .disconnected }
    try await waitUntilAsync {
      await diagnosticLogger.containsCancellation(source: .systemEnvironmentChange)
    }

    monitor.setSystemEnvironmentAvailable(false)
    monitor.setSystemEnvironmentAvailable(true)
    try await waitUntilAsync { await collector.collectionCount == 2 }

    let didUseRecoveryTrigger = await diagnosticLogger.contains(
      .connectionAttemptStarted(trigger: .systemRecovery, attemptNumber: 1)
    )
    XCTAssertTrue(didUseRecoveryTrigger)
    monitor.disconnect()
  }

  func testUserDisconnectWhilePausedPreventsRecovery() async throws {
    let collector = MonitorTestCollector(
      snapshot: MihomoConnectionsSnapshot(
        downloadTotal: 2_000,
        uploadTotal: 1_000,
        connections: []
      )
    )
    let (userDefaults, suiteName) = makeUserDefaults()
    defer {
      userDefaults.removePersistentDomain(forName: suiteName)
    }
    userDefaults.set("http://127.0.0.1:9090", forKey: "controllerAddress")
    let monitor = TrafficMonitor(
      client: MonitorTestClient(),
      collector: collector,
      secretStore: MonitorTestSecretStore(secret: "synthetic-secret"),
      userDefaults: userDefaults
    )

    monitor.start()
    try await waitUntil { monitor.connectionState == .connected }
    monitor.setSystemEnvironmentAvailable(false)
    monitor.disconnect()
    monitor.setSystemEnvironmentAvailable(true)
    try await Task.sleep(nanoseconds: 50_000_000)

    let collectionCount = await collector.collectionCount
    XCTAssertEqual(collectionCount, 1)
  }

  func testTerminalAuthenticationFailureDoesNotBecomeRecoveryCandidate() async throws {
    let diagnosticLogger = MonitorTestDiagnosticLogger()
    let (userDefaults, suiteName) = makeUserDefaults()
    defer {
      userDefaults.removePersistentDomain(forName: suiteName)
    }
    userDefaults.set("http://127.0.0.1:9090", forKey: "controllerAddress")
    let monitor = TrafficMonitor(
      client: MonitorTestClient(error: .authenticationFailed),
      collector: MonitorTestCollector(),
      secretStore: MonitorTestSecretStore(secret: "synthetic-secret"),
      diagnosticLogger: diagnosticLogger,
      userDefaults: userDefaults
    )

    monitor.start()
    try await waitUntil { monitor.connectionState == .authenticationFailed }
    monitor.setSystemEnvironmentAvailable(false)
    monitor.setSystemEnvironmentAvailable(true)
    try await Task.sleep(nanoseconds: 50_000_000)

    let startupAttemptCount = await diagnosticLogger.connectionAttemptCount(
      trigger: .applicationStartup
    )
    let recoveryAttemptCount = await diagnosticLogger.connectionAttemptCount(
      trigger: .systemRecovery
    )
    XCTAssertEqual(startupAttemptCount, 1)
    XCTAssertEqual(recoveryAttemptCount, 0)
  }
}
