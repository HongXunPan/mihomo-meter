import Foundation

enum RuntimeQuotaObservationResult: Equatable, Sendable {
  case selection(RuntimeQuotaCandidateSelection)
  case failed(String)
}

typealias RuntimeQuotaObservationHandler =
  @MainActor @Sendable (RuntimeQuotaObservationResult) async -> Void

@MainActor
protocol RuntimeQuotaObserving: AnyObject {
  func start(
    endpoint: ControllerEndpoint,
    secret: String,
    handler: @escaping RuntimeQuotaObservationHandler
  )

  func stop()
}

@MainActor
protocol RuntimeQuotaTrackingLifecycle: AnyObject {
  func controllerValidated(endpoint: ControllerEndpoint, secret: String)
  func controllerUnavailable()
}

@MainActor
final class NoOpRuntimeQuotaTrackingLifecycle: RuntimeQuotaTrackingLifecycle {
  static let shared = NoOpRuntimeQuotaTrackingLifecycle()

  private init() {}

  func controllerValidated(endpoint: ControllerEndpoint, secret: String) {}

  func controllerUnavailable() {}
}
