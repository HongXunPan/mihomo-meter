import Foundation

@MainActor
final class MihomoMonitoringSession {
  struct Completion: Equatable, Sendable {
    let forcedReason: ConnectionDiagnosticReason?
    let shouldResetBackoff: Bool
  }

  enum Event: Equatable, Sendable {
    case measurement(TrafficMeasurementResult)
    case dataStale(
      staleTimeoutSeconds: Int,
      reconnectAfterSeconds: Int,
      lastSnapshotAgeMilliseconds: Int
    )
    case reconnectRequired(lastSnapshotAgeMilliseconds: Int)
  }

  typealias EventHandler = @MainActor @Sendable (Event) async -> Void

  let id = UUID()

  private let client: any MihomoControllerServing
  private let collector: any ConnectionSnapshotCollecting
  private let livenessWatchdog: ConnectionLivenessWatchdog

  private var measurementSession = TrafficMeasurementSession()
  private var catalogRefreshTask: Task<Void, Never>?

  init(
    client: any MihomoControllerServing,
    collector: any ConnectionSnapshotCollecting,
    livenessPolicy: ConnectionLivenessWatchdog.Policy
  ) {
    self.client = client
    self.collector = collector
    livenessWatchdog = ConnectionLivenessWatchdog(policy: livenessPolicy)
  }

  var currentSnapshotAgeMilliseconds: Int? {
    livenessWatchdog.currentSnapshotAgeMilliseconds
  }

  func run(
    endpoint: ControllerEndpoint,
    secret: String,
    catalog: ProxyCatalog,
    eventHandler: @escaping EventHandler
  ) async throws {
    measurementSession.configure(catalog: catalog)
    let streamID = livenessWatchdog.beginStream { [weak self] event in
      await self?.handleLivenessEvent(event, eventHandler: eventHandler)
    }

    try await collector.collect(
      endpoint: endpoint,
      secret: secret
    ) { [weak self] snapshot in
      await self?.consume(
        snapshot,
        endpoint: endpoint,
        secret: secret,
        streamID: streamID,
        eventHandler: eventHandler
      )
    }
    throw ConnectionStreamError.closed
  }

  func finish() -> Completion {
    catalogRefreshTask?.cancel()
    catalogRefreshTask = nil
    let completion = livenessWatchdog.finishStream()
    return Completion(
      forcedReason: completion.forcedReason,
      shouldResetBackoff: completion.shouldResetBackoff
    )
  }

  func cancel() async {
    _ = finish()
    await collector.cancel()
  }

  private func consume(
    _ snapshot: MihomoConnectionsSnapshot,
    endpoint: ControllerEndpoint,
    secret: String,
    streamID: UUID,
    eventHandler: @escaping EventHandler
  ) async {
    guard livenessWatchdog.acceptSnapshot(streamID: streamID),
      let result = measurementSession.consume(snapshot.trafficSnapshot)
    else {
      return
    }

    if result.requiresCatalogRefresh {
      refreshCatalogIfNeeded(endpoint: endpoint, secret: secret)
    }
    await eventHandler(.measurement(result))
  }

  private func refreshCatalogIfNeeded(
    endpoint: ControllerEndpoint,
    secret: String
  ) {
    guard catalogRefreshTask == nil else {
      return
    }

    catalogRefreshTask = Task { [weak self] in
      guard let self else {
        return
      }

      do {
        let proxies = try await client.fetchProxies(endpoint: endpoint, secret: secret)
        guard !Task.isCancelled else {
          catalogRefreshTask = nil
          return
        }
        measurementSession.updateCatalog(
          ProxyCatalog(typesByName: proxies.proxies.mapValues(\.type))
        )
      } catch {
        // 刷新失败不打断当前实时流，后续未知快照会再次尝试。
      }
      catalogRefreshTask = nil
    }
  }

  private func handleLivenessEvent(
    _ event: ConnectionLivenessWatchdog.Event,
    eventHandler: @escaping EventHandler
  ) async {
    switch event {
    case .stale(let streamID, let lastSnapshotAgeMilliseconds):
      guard livenessWatchdog.isCurrentStream(streamID) else {
        return
      }
      await eventHandler(
        .dataStale(
          staleTimeoutSeconds: livenessWatchdog.policy.staleTimeoutSeconds,
          reconnectAfterSeconds: livenessWatchdog.policy.reconnectTimeoutSeconds,
          lastSnapshotAgeMilliseconds: lastSnapshotAgeMilliseconds
        )
      )
    case .reconnectRequired(let streamID, let lastSnapshotAgeMilliseconds):
      guard
        livenessWatchdog.requestTermination(
          streamID: streamID,
          reason: .dataStale
        )
      else {
        return
      }
      await eventHandler(
        .reconnectRequired(
          lastSnapshotAgeMilliseconds: lastSnapshotAgeMilliseconds
        )
      )
      await collector.cancel()
    }
  }
}
