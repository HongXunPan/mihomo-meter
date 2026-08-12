import Foundation

@MainActor
final class TrafficMonitoringRun {
  typealias EventHandler = @MainActor @Sendable (TrafficMonitoringEvent) -> Void

  private let client: any MihomoControllerServing
  private let collector: any ConnectionSnapshotCollecting
  private let configurationStore: ControllerConfigurationStore
  private let diagnosticLogger: any AppDiagnosticLogging
  private let livenessPolicy: ConnectionLivenessWatchdog.Policy
  private let statisticsRecorder: any TrafficStatisticsRecording
  private let connectionAnalyticsRecorder: any ConnectionAnalyticsRecording

  private var activeSession: MihomoMonitoringSession?
  private var hasEstablishedCurrentSession = false
  private var isCancelled = false

  init(
    client: any MihomoControllerServing,
    collector: any ConnectionSnapshotCollecting,
    configurationStore: ControllerConfigurationStore,
    diagnosticLogger: any AppDiagnosticLogging,
    livenessPolicy: ConnectionLivenessWatchdog.Policy,
    statisticsRecorder: any TrafficStatisticsRecording,
    connectionAnalyticsRecorder: any ConnectionAnalyticsRecording
  ) {
    self.client = client
    self.collector = collector
    self.configurationStore = configurationStore
    self.diagnosticLogger = diagnosticLogger
    self.livenessPolicy = livenessPolicy
    self.statisticsRecorder = statisticsRecorder
    self.connectionAnalyticsRecorder = connectionAnalyticsRecorder
  }

  var currentSnapshotAgeMilliseconds: Int? {
    activeSession?.currentSnapshotAgeMilliseconds
  }

  func cancel() async {
    isCancelled = true
    let session = activeSession
    activeSession = nil
    await session?.cancel()
  }

  func execute(
    address: String,
    secret: String,
    initialTrigger: ConnectionAttemptTrigger,
    eventHandler: @escaping EventHandler
  ) async {
    let endpoint: ControllerEndpoint
    do {
      endpoint = try ControllerEndpoint(address: address)
    } catch {
      await stopWithError(error, eventHandler: eventHandler)
      return
    }

    var backoff = ReconnectBackoff()
    var isFirstAttempt = true
    var attemptNumber = 1

    while !Task.isCancelled, !isCancelled {
      var session: MihomoMonitoringSession?
      if !isFirstAttempt {
        eventHandler(.retrying)
      }
      await diagnosticLogger.record(
        .connectionAttemptStarted(
          trigger: isFirstAttempt ? initialTrigger : .automaticRetry,
          attemptNumber: attemptNumber
        )
      )

      do {
        let version = try await client.fetchVersion(endpoint: endpoint, secret: secret)
        let proxies = try await client.fetchProxies(endpoint: endpoint, secret: secret)
        let runtimeConfiguration = await fetchRuntimeConfiguration(
          endpoint: endpoint,
          secret: secret
        )
        if isFirstAttempt, initialTrigger == .userRequest {
          try await configurationStore.saveValidatedSecret(secret)
        }
        guard !Task.isCancelled, !isCancelled else {
          return
        }

        await statisticsRecorder.beginMonitoring(version: version.version, at: Date())
        configurationStore.saveValidatedAddress(endpoint)
        let monitoringSession = MihomoMonitoringSession(
          client: client,
          collector: collector,
          livenessPolicy: livenessPolicy,
          resolveProxyType: SharedCoreProxyTypeRoute.resolve
        )
        session = monitoringSession
        activeSession = monitoringSession
        hasEstablishedCurrentSession = false
        eventHandler(
          .validated(
            address: endpoint.baseURL.absoluteString,
            version: version.version,
            runtimeConfiguration: runtimeConfiguration
          )
        )

        try await monitoringSession.run(
          endpoint: endpoint,
          secret: secret,
          catalog: ProxyCatalog(typesByName: proxies.proxies.mapValues(\.type))
        ) { [weak self] event in
          await self?.handleSessionEvent(
            event,
            sessionID: monitoringSession.id,
            eventHandler: eventHandler
          )
        }
      } catch is CancellationError {
        _ = finish(session)
        return
      } catch {
        guard !Task.isCancelled, !isCancelled else {
          return
        }
        if let terminal = terminalOutcome(for: error) {
          _ = finish(session)
          await statisticsRecorder.interruptMonitoring(at: Date())
          await diagnosticLogger.record(
            .connectionStopped(reason: .classify(error))
          )
          eventHandler(
            .terminal(state: terminal.state, message: terminal.message)
          )
          return
        }

        let completion = finish(session)
        if completion.shouldResetBackoff {
          backoff.reset()
        }
        let reason =
          completion.forcedReason
          ?? ConnectionDiagnosticReason.classify(error)
        let message =
          reason == .dataStale
          ? "实时数据持续超时，等待重新连接。"
          : error.localizedDescription
        let delay = backoff.nextDelaySeconds()
        eventHandler(.reconnectScheduled(reason: reason, message: message))
        await diagnosticLogger.record(
          .connectionReconnectScheduled(
            reason: reason,
            delaySeconds: delay
          )
        )
        do {
          try await Task.sleep(nanoseconds: delay * 1_000_000_000)
        } catch {
          return
        }
        isFirstAttempt = false
        attemptNumber += 1
      }
    }
  }

  private func handleSessionEvent(
    _ event: MihomoMonitoringSession.Event,
    sessionID: UUID,
    eventHandler: @escaping EventHandler
  ) async {
    guard !isCancelled, activeSession?.id == sessionID else {
      return
    }

    switch event {
    case .measurement(let result):
      if !hasEstablishedCurrentSession {
        hasEstablishedCurrentSession = true
        await diagnosticLogger.record(.connectionEstablished)
      }
      await statisticsRecorder.record(result.ledgerObservation)
      await connectionAnalyticsRecorder.record(
        result.connectionAttributionDeltas,
        at: result.ledgerObservation.observedAt
      )
      eventHandler(.measurement(result))
    case .dataStale(
      let staleTimeoutSeconds,
      let reconnectAfterSeconds,
      let lastSnapshotAgeMilliseconds
    ):
      eventHandler(
        .dataStale(
          staleTimeoutSeconds: staleTimeoutSeconds,
          reconnectAfterSeconds: reconnectAfterSeconds,
          lastSnapshotAgeMilliseconds: lastSnapshotAgeMilliseconds
        )
      )
      await diagnosticLogger.record(
        .connectionDataStale(
          timeoutSeconds: staleTimeoutSeconds,
          reconnectAfterSeconds: reconnectAfterSeconds,
          lastSnapshotAgeMilliseconds: lastSnapshotAgeMilliseconds
        )
      )
    case .reconnectRequired(let lastSnapshotAgeMilliseconds):
      eventHandler(.reconnectRequired)
      await diagnosticLogger.record(
        .connectionCancellationRequested(
          source: .staleWatchdog,
          lastSnapshotAgeMilliseconds: lastSnapshotAgeMilliseconds
        )
      )
    }
  }

  private func stopWithError(
    _ error: any Error,
    eventHandler: @escaping EventHandler
  ) async {
    guard !isCancelled else {
      return
    }
    await statisticsRecorder.interruptMonitoring(at: Date())
    await diagnosticLogger.record(
      .connectionStopped(reason: .classify(error))
    )
    eventHandler(
      .terminal(state: .disconnected, message: error.localizedDescription)
    )
  }

  private func fetchRuntimeConfiguration(
    endpoint: ControllerEndpoint,
    secret: String
  ) async -> MihomoRuntimeConfiguration? {
    do {
      return try await client.fetchRuntimeConfiguration(
        endpoint: endpoint,
        secret: secret
      )
    } catch {
      await diagnosticLogger.record(
        .runtimeConfigurationUnavailable(
          reason: .classify(error)
        )
      )
      return nil
    }
  }

  private func finish(
    _ session: MihomoMonitoringSession?
  ) -> MihomoMonitoringSession.Completion {
    guard let session else {
      return MihomoMonitoringSession.Completion(
        forcedReason: nil,
        shouldResetBackoff: false
      )
    }
    if activeSession?.id == session.id {
      activeSession = nil
    }
    return session.finish()
  }

  private func terminalOutcome(
    for error: any Error
  ) -> (state: MonitorConnectionState, message: String)? {
    switch error {
    case MihomoControllerError.authenticationFailed:
      (.authenticationFailed, error.localizedDescription)
    case MihomoControllerError.unsupportedResponse,
      ConnectionStreamError.unsupportedResponse:
      (.unsupported, error.localizedDescription)
    case is KeychainSecretStoreError:
      (.disconnected, error.localizedDescription)
    default:
      nil
    }
  }
}
