import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class TrafficMonitorLifecycleTests: TrafficMonitorTestCase {
  func testUserDisconnectWritesTypedCancellationSource() async throws {
    let diagnosticLogger = MonitorTestDiagnosticLogger()
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
      diagnosticLogger: diagnosticLogger,
      userDefaults: userDefaults
    )
    monitor.address = "127.0.0.1:9090"

    monitor.connect()
    try await waitUntil {
      monitor.connectionState == .connected
    }
    monitor.disconnect()

    try await waitUntilAsync {
      await diagnosticLogger.containsCancellation(source: .userDisconnect)
    }
    let snapshotAge = await diagnosticLogger.cancellationAge(source: .userDisconnect)
    XCTAssertNotNil(snapshotAge)
  }

  func testMarksSnapshotAsStaleBeforeCancellingStream() async throws {
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
    let monitor = TrafficMonitor(
      client: MonitorTestClient(),
      collector: collector,
      secretStore: MonitorTestSecretStore(),
      diagnosticLogger: diagnosticLogger,
      livenessPolicy: .init(
        staleAfterNanoseconds: 40_000_000,
        reconnectAfterNanoseconds: 120_000_000,
        backoffResetAfterNanoseconds: 1_000_000_000
      ),
      userDefaults: userDefaults
    )
    monitor.address = "127.0.0.1:9090"

    monitor.connect()
    try await waitUntil {
      monitor.connectionState == .connected
    }
    let cancellationCountBeforeStale = await collector.cancellationCount

    try await waitUntil {
      monitor.connectionState == .stale
    }

    XCTAssertEqual(monitor.rates, .zero)
    let cancellationCountAtStale = await collector.cancellationCount
    XCTAssertEqual(cancellationCountAtStale, cancellationCountBeforeStale)

    try await waitUntilAsync {
      await diagnosticLogger.containsCancellation(source: .staleWatchdog)
    }
    try await waitUntilAsync {
      await diagnosticLogger.contains(
        .connectionReconnectScheduled(
          reason: .dataStale,
          delaySeconds: 1
        )
      )
    }
    let cancellationCountAfterReconnect = await collector.cancellationCount
    XCTAssertGreaterThan(cancellationCountAfterReconnect, cancellationCountAtStale)
    monitor.disconnect()
  }

  func testRefreshesProxyCatalogWhenSnapshotContainsUnknownLeaf() async throws {
    let client = MonitorTestClient()
    let collector = MonitorTestCollector(
      snapshot: MihomoConnectionsSnapshot(
        downloadTotal: 2_000,
        uploadTotal: 1_000,
        connections: [
          MihomoConnectionResponse(
            id: "synthetic-new-node",
            upload: 10,
            download: 20,
            chains: ["Synthetic New Node"]
          )
        ]
      )
    )
    let (userDefaults, suiteName) = makeUserDefaults()
    defer {
      userDefaults.removePersistentDomain(forName: suiteName)
    }
    let monitor = TrafficMonitor(
      client: client,
      collector: collector,
      secretStore: MonitorTestSecretStore(),
      userDefaults: userDefaults
    )
    monitor.address = "127.0.0.1:9090"

    monitor.connect()
    try await waitUntilAsync {
      await client.proxyFetchCount >= 2
    }

    monitor.disconnect()
  }

  func testKeepsMonitoringWhenRuntimeConfigurationIsUnavailable() async throws {
    let diagnosticLogger = MonitorTestDiagnosticLogger()
    let client = MonitorTestClient(
      runtimeConfigurationError: .httpStatus(500)
    )
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
    let monitor = TrafficMonitor(
      client: client,
      collector: collector,
      secretStore: MonitorTestSecretStore(),
      diagnosticLogger: diagnosticLogger,
      userDefaults: userDefaults
    )
    monitor.address = "127.0.0.1:9090"

    monitor.connect()
    try await waitUntil {
      monitor.connectionState == .connected
    }

    XCTAssertNil(monitor.runtimeConfiguration)
    let didLogUnavailableConfiguration = await diagnosticLogger.contains(
      .runtimeConfigurationUnavailable(reason: .controllerHTTP(500))
    )
    XCTAssertTrue(didLogUnavailableConfiguration)
    monitor.disconnect()
  }

  func testLogsAutomaticReconnectReasonAndDelay() async throws {
    let diagnosticLogger = MonitorTestDiagnosticLogger()
    let collector = MonitorTestCollector(error: .closed)
    let (userDefaults, suiteName) = makeUserDefaults()
    defer {
      userDefaults.removePersistentDomain(forName: suiteName)
    }
    let monitor = TrafficMonitor(
      client: MonitorTestClient(),
      collector: collector,
      secretStore: MonitorTestSecretStore(),
      diagnosticLogger: diagnosticLogger,
      userDefaults: userDefaults
    )
    monitor.address = "127.0.0.1:9090"

    monitor.connect()
    try await waitUntilAsync {
      await diagnosticLogger.contains(
        .connectionReconnectScheduled(
          reason: .streamClosed,
          delaySeconds: 1
        )
      )
    }

    monitor.disconnect()
  }

  func testImmediateReconnectUsesDedicatedDiagnosticTrigger() async throws {
    let diagnosticLogger = MonitorTestDiagnosticLogger()
    let (userDefaults, suiteName) = makeUserDefaults()
    defer {
      userDefaults.removePersistentDomain(forName: suiteName)
    }
    let monitor = TrafficMonitor(
      client: MonitorTestClient(error: .authenticationFailed),
      collector: MonitorTestCollector(),
      secretStore: MonitorTestSecretStore(),
      diagnosticLogger: diagnosticLogger,
      userDefaults: userDefaults
    )
    monitor.address = "127.0.0.1:9090"

    monitor.reconnectNow()
    try await waitUntilAsync {
      await diagnosticLogger.contains(
        .connectionAttemptStarted(
          trigger: .immediateRetry,
          attemptNumber: 1
        )
      )
    }
    try await waitUntil { monitor.connectionState == .authenticationFailed }

    let didLogTerminalReason = await diagnosticLogger.contains(
      .connectionStopped(reason: .authenticationFailed)
    )
    XCTAssertTrue(didLogTerminalReason)
  }
}
