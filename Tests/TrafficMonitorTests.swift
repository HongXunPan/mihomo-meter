import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class TrafficMonitorTests: XCTestCase {
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
    XCTAssertEqual(monitor.mihomoVersion, "v-test")
    XCTAssertEqual(savedSecret, "synthetic-secret")
    XCTAssertEqual(
      userDefaults.string(forKey: "controllerAddress"),
      "http://127.0.0.1:9090"
    )

    monitor.disconnect()
  }

  func testMarksSnapshotAsStaleAfterTwoSecondsWithoutUpdates() async throws {
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
      userDefaults: userDefaults
    )
    monitor.address = "127.0.0.1:9090"

    monitor.connect()
    try await waitUntil(timeoutNanoseconds: 3_000_000_000) {
      monitor.connectionState == .stale
    }

    XCTAssertEqual(monitor.rates, .zero)
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

  private func makeUserDefaults() -> (UserDefaults, String) {
    let suiteName = "MihomoMeterTests.\(UUID().uuidString)"
    return (UserDefaults(suiteName: suiteName) ?? .standard, suiteName)
  }

  private func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping @MainActor () -> Bool
  ) async throws {
    let intervalNanoseconds: UInt64 = 10_000_000
    var waitedNanoseconds: UInt64 = 0

    while !condition(), waitedNanoseconds < timeoutNanoseconds {
      try await Task.sleep(nanoseconds: intervalNanoseconds)
      waitedNanoseconds += intervalNanoseconds
    }

    XCTAssertTrue(condition(), "等待状态变化超时")
  }

  private func waitUntilAsync(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping () async -> Bool
  ) async throws {
    let intervalNanoseconds: UInt64 = 10_000_000
    var waitedNanoseconds: UInt64 = 0

    while !(await condition()), waitedNanoseconds < timeoutNanoseconds {
      try await Task.sleep(nanoseconds: intervalNanoseconds)
      waitedNanoseconds += intervalNanoseconds
    }

    let didFinish = await condition()
    XCTAssertTrue(didFinish, "等待异步状态变化超时")
  }
}

private actor MonitorTestClient: MihomoControllerServing {
  private let error: MihomoControllerError?
  private(set) var proxyFetchCount = 0

  init(error: MihomoControllerError? = nil) {
    self.error = error
  }

  func fetchVersion(
    endpoint: ControllerEndpoint,
    secret: String
  ) async throws -> MihomoVersionResponse {
    if let error {
      throw error
    }
    return MihomoVersionResponse(meta: true, version: "v-test")
  }

  func fetchProxies(
    endpoint: ControllerEndpoint,
    secret: String
  ) async throws -> MihomoProxiesResponse {
    proxyFetchCount += 1
    return MihomoProxiesResponse(proxies: [:])
  }
}

private actor MonitorTestCollector: ConnectionSnapshotCollecting {
  private let snapshot: MihomoConnectionsSnapshot?
  private let error: ConnectionStreamError?
  private(set) var collectionCount = 0

  init(
    snapshot: MihomoConnectionsSnapshot? = nil,
    error: ConnectionStreamError? = nil
  ) {
    self.snapshot = snapshot
    self.error = error
  }

  func collect(
    endpoint: ControllerEndpoint,
    secret: String,
    onSnapshot: @escaping ConnectionSnapshotHandler
  ) async throws {
    collectionCount += 1
    if let snapshot {
      await onSnapshot(snapshot)
    }
    if let error {
      throw error
    }
    try await Task.sleep(nanoseconds: UInt64.max)
  }

  func cancel() {}
}

private actor MonitorTestDiagnosticLogger: AppDiagnosticLogging {
  private var events: [AppDiagnosticEvent] = []

  func record(_ event: AppDiagnosticEvent) {
    events.append(event)
  }

  func contains(_ event: AppDiagnosticEvent) -> Bool {
    events.contains(event)
  }
}

private actor MonitorTestSecretStore: ControllerSecretStoring {
  private var secret: String?

  func loadSecret(reason: KeychainAccessReason) -> String? {
    secret
  }

  func saveSecret(_ secret: String, reason: KeychainAccessReason) {
    self.secret = secret
  }

  func deleteSecret(reason: KeychainAccessReason) {
    secret = nil
  }
}
