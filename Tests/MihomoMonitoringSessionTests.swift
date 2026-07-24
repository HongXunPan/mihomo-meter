import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class MihomoMonitoringSessionTests: XCTestCase {
  func testUnknownProxyLeafRequestsCatalogRefresh() async throws {
    let client = MonitoringSessionTestClient()
    let collector = MonitoringSessionTestCollector(
      snapshots: [
        MihomoConnectionsSnapshot(
          downloadTotal: 20,
          uploadTotal: 10,
          connections: [
            MihomoConnectionResponse(
              id: "synthetic-connection",
              upload: 10,
              download: 20,
              chains: ["Synthetic Proxy"]
            )
          ]
        )
      ]
    )
    let session = MihomoMonitoringSession(
      client: client,
      collector: collector,
      livenessPolicy: .production
    )
    var events: [MihomoMonitoringSession.Event] = []

    let runTask = Task {
      try? await session.run(
        endpoint: try ControllerEndpoint(address: "127.0.0.1:9090"),
        secret: "",
        catalog: ProxyCatalog(typesByName: [:])
      ) { event in
        events.append(event)
      }
    }

    try await waitUntil {
      events.contains { event in
        guard case .measurement(let result) = event else {
          return false
        }
        return result.requiresCatalogRefresh
      }
    }
    try await waitUntilAsync {
      await client.proxyFetchCount == 1
    }

    await session.cancel()
    await runTask.value
  }

  func testStaleStreamRequestsReconnectAndPreservesForcedReason() async throws {
    let collector = MonitoringSessionTestCollector()
    let session = MihomoMonitoringSession(
      client: MonitoringSessionTestClient(),
      collector: collector,
      livenessPolicy: .init(
        staleAfterNanoseconds: 30_000_000,
        reconnectAfterNanoseconds: 80_000_000,
        backoffResetAfterNanoseconds: 1_000_000_000
      )
    )
    var events: [MihomoMonitoringSession.Event] = []

    let runTask = Task {
      try? await session.run(
        endpoint: try ControllerEndpoint(address: "127.0.0.1:9090"),
        secret: "",
        catalog: ProxyCatalog(typesByName: [:])
      ) { event in
        events.append(event)
      }
    }

    try await waitUntil {
      events.contains { event in
        guard case .dataStale = event else {
          return false
        }
        return true
      }
    }
    try await waitUntil {
      events.contains { event in
        guard case .reconnectRequired = event else {
          return false
        }
        return true
      }
    }
    await runTask.value

    let completion = session.finish()
    XCTAssertEqual(completion.forcedReason, .dataStale)
    let cancellationCount = await collector.cancellationCount
    XCTAssertEqual(cancellationCount, 1)
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

    XCTAssertTrue(condition(), "等待监控会话事件超时")
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
    XCTAssertTrue(didFinish, "等待监控会话异步状态超时")
  }
}

private actor MonitoringSessionTestClient: MihomoControllerServing {
  private(set) var proxyFetchCount = 0

  func fetchVersion(
    endpoint: ControllerEndpoint,
    secret: String
  ) async throws -> MihomoVersionResponse {
    MihomoVersionResponse(meta: true, version: "v-test")
  }

  func fetchProxies(
    endpoint: ControllerEndpoint,
    secret: String
  ) async throws -> MihomoProxiesResponse {
    proxyFetchCount += 1
    return MihomoProxiesResponse(proxies: [:])
  }
}

private actor MonitoringSessionTestCollector: ConnectionSnapshotCollecting {
  private let snapshots: [MihomoConnectionsSnapshot]
  private(set) var cancellationCount = 0
  private var pendingContinuation: CheckedContinuation<Void, any Error>?

  init(snapshots: [MihomoConnectionsSnapshot] = []) {
    self.snapshots = snapshots
  }

  func collect(
    endpoint: ControllerEndpoint,
    secret: String,
    onSnapshot: @escaping ConnectionSnapshotHandler
  ) async throws {
    for snapshot in snapshots {
      await onSnapshot(snapshot)
    }
    try await withCheckedThrowingContinuation { continuation in
      pendingContinuation = continuation
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
