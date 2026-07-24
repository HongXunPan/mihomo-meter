import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
class TrafficMonitorTestCase: XCTestCase {
  func makeUserDefaults() -> (UserDefaults, String) {
    let suiteName = "MihomoMeterTests.\(UUID().uuidString)"
    return (UserDefaults(suiteName: suiteName) ?? .standard, suiteName)
  }

  func waitUntil(
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

  func waitUntilAsync(
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

actor MonitorTestClient: MihomoControllerServing {
  private let error: MihomoControllerError?
  private let runtimeConfigurationError: MihomoControllerError?
  private(set) var proxyFetchCount = 0

  init(
    error: MihomoControllerError? = nil,
    runtimeConfigurationError: MihomoControllerError? = nil
  ) {
    self.error = error
    self.runtimeConfigurationError = runtimeConfigurationError
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

  func fetchRuntimeConfiguration(
    endpoint: ControllerEndpoint,
    secret: String
  ) async throws -> MihomoRuntimeConfiguration {
    if let runtimeConfigurationError {
      throw runtimeConfigurationError
    }
    return MihomoRuntimeConfiguration(
      mode: "rule",
      tun: MihomoTunRuntimeConfiguration(
        isEnabled: true,
        stack: "system",
        automaticallyRoutesTraffic: true
      ),
      isIPv6Enabled: true,
      allowsLAN: false,
      mixedPort: 7_890
    )
  }
}

actor MonitorTestCollector: ConnectionSnapshotCollecting {
  private let snapshot: MihomoConnectionsSnapshot?
  private let error: ConnectionStreamError?
  private(set) var collectionCount = 0
  private(set) var cancellationCount = 0
  private var pendingContinuation: CheckedContinuation<Void, any Error>?

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
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        pendingContinuation = continuation
      }
    } onCancel: {
      Task {
        await self.cancel()
      }
    }
  }

  func cancel() {
    cancellationCount += 1
    let continuation = pendingContinuation
    pendingContinuation = nil
    continuation?.resume(
      throwing: ConnectionStreamError.network(.cancelled)
    )
  }
}

actor MonitorTestDiagnosticLogger: AppDiagnosticLogging {
  private var events: [AppDiagnosticEvent] = []

  func record(_ event: AppDiagnosticEvent) {
    events.append(event)
  }

  func contains(_ event: AppDiagnosticEvent) -> Bool {
    events.contains(event)
  }

  func containsCancellation(
    source: ConnectionCancellationSource
  ) -> Bool {
    events.contains { event in
      guard case .connectionCancellationRequested(let actualSource, _) = event else {
        return false
      }
      return actualSource == source
    }
  }

  func cancellationAge(
    source: ConnectionCancellationSource
  ) -> Int? {
    for event in events {
      guard
        case .connectionCancellationRequested(
          let actualSource,
          let lastSnapshotAgeMilliseconds
        ) = event,
        actualSource == source
      else {
        continue
      }
      return lastSnapshotAgeMilliseconds
    }
    return nil
  }
}

actor MonitorTestSecretStore: ControllerSecretStoring {
  private var secret: String?
  private(set) var saveCount = 0

  init(secret: String? = nil) {
    self.secret = secret
  }

  func loadSecret(reason: KeychainAccessReason) -> String? {
    secret
  }

  func saveSecret(_ secret: String, reason: KeychainAccessReason) {
    saveCount += 1
    self.secret = secret
  }

  func deleteSecret(reason: KeychainAccessReason) {
    secret = nil
  }
}
