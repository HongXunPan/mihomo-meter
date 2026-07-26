import Foundation

@MainActor
final class RuntimeQuotaObservationCoordinator: RuntimeQuotaObserving {
  private static let productionIntervalNanoseconds: UInt64 = 300_000_000_000

  private let client: any MihomoQuotaProviderServing
  private let intervalNanoseconds: UInt64
  private var observationTask: Task<Void, Never>?
  private var generation = UUID()

  init(
    client: any MihomoQuotaProviderServing,
    intervalNanoseconds: UInt64 = productionIntervalNanoseconds
  ) {
    self.client = client
    self.intervalNanoseconds = intervalNanoseconds
  }

  deinit {
    observationTask?.cancel()
  }

  func start(
    endpoint: ControllerEndpoint,
    secret: String,
    handler: @escaping RuntimeQuotaObservationHandler
  ) {
    stop()
    let generation = UUID()
    self.generation = generation
    observationTask = Task { [weak self] in
      guard let self else {
        return
      }
      await observeRepeatedly(
        endpoint: endpoint,
        secret: secret,
        generation: generation,
        handler: handler
      )
    }
  }

  func stop() {
    generation = UUID()
    observationTask?.cancel()
    observationTask = nil
  }

  private func observeRepeatedly(
    endpoint: ControllerEndpoint,
    secret: String,
    generation: UUID,
    handler: @escaping RuntimeQuotaObservationHandler
  ) async {
    while !Task.isCancelled, self.generation == generation {
      await observeOnce(
        endpoint: endpoint,
        secret: secret,
        generation: generation,
        handler: handler
      )
      do {
        try await Task.sleep(nanoseconds: intervalNanoseconds)
      } catch {
        return
      }
    }
  }

  private func observeOnce(
    endpoint: ControllerEndpoint,
    secret: String,
    generation: UUID,
    handler: @escaping RuntimeQuotaObservationHandler
  ) async {
    do {
      let response = try await client.fetchProxyProviders(
        endpoint: endpoint,
        secret: secret
      )
      guard !Task.isCancelled, self.generation == generation else {
        return
      }
      await handler(.selection(response.runtimeQuotaSelection))
    } catch {
      guard !Task.isCancelled, self.generation == generation else {
        return
      }
      await handler(.failed(error.localizedDescription))
    }
  }
}
