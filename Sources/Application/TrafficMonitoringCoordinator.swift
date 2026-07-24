import Foundation

enum TrafficMonitoringEvent: Equatable, Sendable {
  case validating
  case retrying
  case validated(address: String, version: String)
  case measurement(TrafficMeasurementResult)
  case dataStale(
    staleTimeoutSeconds: Int,
    reconnectAfterSeconds: Int,
    lastSnapshotAgeMilliseconds: Int
  )
  case reconnectRequired
  case reconnectScheduled(reason: ConnectionDiagnosticReason, message: String)
  case terminal(state: MonitorConnectionState, message: String)
  case stopped
}

@MainActor
final class TrafficMonitoringCoordinator {
  typealias Event = TrafficMonitoringEvent
  typealias EventHandler = @MainActor @Sendable (Event) -> Void

  private let client: any MihomoControllerServing
  private let collector: any ConnectionSnapshotCollecting
  private let configurationStore: ControllerConfigurationStore
  private let diagnosticLogger: any AppDiagnosticLogging
  private let livenessPolicy: ConnectionLivenessWatchdog.Policy

  private var connectionTask: Task<Void, Never>?
  private var activeRun: TrafficMonitoringRun?
  private var runID = UUID()
  private var isActive = false

  init(
    client: any MihomoControllerServing,
    collector: any ConnectionSnapshotCollecting,
    configurationStore: ControllerConfigurationStore,
    diagnosticLogger: any AppDiagnosticLogging,
    livenessPolicy: ConnectionLivenessWatchdog.Policy
  ) {
    self.client = client
    self.collector = collector
    self.configurationStore = configurationStore
    self.diagnosticLogger = diagnosticLogger
    self.livenessPolicy = livenessPolicy
  }

  func start(
    address: String,
    secret: String,
    trigger: ConnectionAttemptTrigger,
    eventHandler: @escaping EventHandler
  ) {
    let cancellationSource = isActive ? cancellationSource(for: trigger) : nil
    let lastSnapshotAgeMilliseconds =
      activeRun?.currentSnapshotAgeMilliseconds
    let previousRun = activeRun
    let newRunID = UUID()
    let run = makeRun()
    runID = newRunID

    connectionTask?.cancel()
    activeRun = run
    isActive = true
    eventHandler(.validating)

    connectionTask = Task { [weak self] in
      guard let self else {
        return
      }
      if let cancellationSource {
        await diagnosticLogger.record(
          .connectionCancellationRequested(
            source: cancellationSource,
            lastSnapshotAgeMilliseconds: lastSnapshotAgeMilliseconds
          )
        )
      }
      await previousRun?.cancel()
      await run.execute(
        address: address,
        secret: secret,
        initialTrigger: trigger
      ) { [weak self] event in
        guard let self, runID == newRunID else {
          return
        }
        eventHandler(event)
      }
      guard runID == newRunID else {
        return
      }
      activeRun = nil
      isActive = false
    }
  }

  func stop(
    source: ConnectionCancellationSource,
    eventHandler: @escaping EventHandler
  ) {
    let shouldLogCancellation = isActive
    let lastSnapshotAgeMilliseconds =
      activeRun?.currentSnapshotAgeMilliseconds
    let run = activeRun
    runID = UUID()
    connectionTask?.cancel()
    connectionTask = nil
    activeRun = nil
    isActive = false

    Task { [diagnosticLogger] in
      if shouldLogCancellation {
        await diagnosticLogger.record(
          .connectionCancellationRequested(
            source: source,
            lastSnapshotAgeMilliseconds: lastSnapshotAgeMilliseconds
          )
        )
      }
      await run?.cancel()
    }
    eventHandler(.stopped)
  }

  private func makeRun() -> TrafficMonitoringRun {
    TrafficMonitoringRun(
      client: client,
      collector: collector,
      configurationStore: configurationStore,
      diagnosticLogger: diagnosticLogger,
      livenessPolicy: livenessPolicy
    )
  }

  private func cancellationSource(
    for trigger: ConnectionAttemptTrigger
  ) -> ConnectionCancellationSource {
    switch trigger {
    case .immediateRetry:
      .immediateRetry
    case .applicationStartup, .userRequest, .automaticRetry:
      .userConnectionRequest
    }
  }
}
