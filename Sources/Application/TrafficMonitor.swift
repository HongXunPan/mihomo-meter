import Combine
import Foundation

@MainActor
final class TrafficMonitor: ObservableObject {
  @Published var address: String
  @Published var secret: String
  @Published private(set) var connectionState: MonitorConnectionState = .disconnected
  @Published private(set) var rates: CategorizedTrafficRates = .zero
  @Published private(set) var rawRates: CategorizedTrafficRates = .zero
  @Published private(set) var coverage: Double?
  @Published private(set) var activeProxyLeaves: [String] = []
  @Published private(set) var mihomoVersion: String?
  @Published private(set) var message = "请输入本机 Mihomo 服务地址和访问密钥。"

  private static let addressDefaultsKey = "controllerAddress"

  private let client: any MihomoControllerServing
  private let collector: any ConnectionSnapshotCollecting
  private let secretStore: any ControllerSecretStoring
  private let diagnosticLogger: any AppDiagnosticLogging
  private let livenessWatchdog: ConnectionLivenessWatchdog
  private let userDefaults: UserDefaults

  private var connectionTask: Task<Void, Never>?
  private var catalogRefreshTask: Task<Void, Never>?
  private var runID = UUID()
  private var measurementSession = TrafficMeasurementSession()

  init(
    client: any MihomoControllerServing = MihomoControllerClient(),
    collector: any ConnectionSnapshotCollecting = ConnectionStreamCollector(),
    secretStore: any ControllerSecretStoring = KeychainSecretStore(),
    diagnosticLogger: any AppDiagnosticLogging = NoOpAppDiagnosticLogger.shared,
    livenessPolicy: ConnectionLivenessWatchdog.Policy = .production,
    userDefaults: UserDefaults = .standard
  ) {
    self.client = client
    self.collector = collector
    self.secretStore = secretStore
    self.diagnosticLogger = diagnosticLogger
    livenessWatchdog = ConnectionLivenessWatchdog(policy: livenessPolicy)
    self.userDefaults = userDefaults
    address = userDefaults.string(forKey: Self.addressDefaultsKey) ?? ""
    secret = ""
  }

  func start() {
    let savedAddress = address
    Task { [weak self] in
      guard let self else {
        return
      }

      do {
        secret = try await secretStore.loadSecret(reason: .applicationStartup) ?? ""
        if !savedAddress.isEmpty {
          startConnection(trigger: .applicationStartup)
        }
      } catch {
        connectionState = .disconnected
        message = error.localizedDescription
      }
    }
  }

  func connect() {
    startConnection(trigger: .userRequest)
  }

  func reconnectNow() {
    startConnection(trigger: .immediateRetry)
  }

  private func startConnection(trigger: ConnectionAttemptTrigger) {
    let requestedAddress = address
    let requestedSecret = secret
    let cancellationSource =
      isConnectionActive ? cancellationSource(for: trigger) : nil
    let lastSnapshotAgeMilliseconds =
      livenessWatchdog.currentSnapshotAgeMilliseconds
    let newRunID = UUID()
    runID = newRunID

    connectionTask?.cancel()
    livenessWatchdog.cancel()
    catalogRefreshTask?.cancel()
    catalogRefreshTask = nil
    resetLiveData()
    mihomoVersion = nil
    connectionState = .connecting
    message = "正在验证 Mihomo 服务…"

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
      await collector.cancel()
      await runConnectionLoop(
        address: requestedAddress,
        secret: requestedSecret,
        initialTrigger: trigger,
        runID: newRunID
      )
    }
  }

  func disconnect() {
    stopConnection(source: .userDisconnect)
  }

  func stopForApplicationTermination() {
    stopConnection(source: .applicationTermination)
  }

  private func stopConnection(source: ConnectionCancellationSource) {
    let shouldLogCancellation = isConnectionActive
    let lastSnapshotAgeMilliseconds =
      livenessWatchdog.currentSnapshotAgeMilliseconds
    runID = UUID()
    connectionTask?.cancel()
    connectionTask = nil
    livenessWatchdog.cancel()
    catalogRefreshTask?.cancel()
    catalogRefreshTask = nil
    Task { [collector, diagnosticLogger] in
      if shouldLogCancellation {
        await diagnosticLogger.record(
          .connectionCancellationRequested(
            source: source,
            lastSnapshotAgeMilliseconds: lastSnapshotAgeMilliseconds
          )
        )
      }
      await collector.cancel()
    }
    resetLiveData()
    mihomoVersion = nil
    connectionState = .disconnected
    message = "监控已停止。"
  }

  private func runConnectionLoop(
    address: String,
    secret: String,
    initialTrigger: ConnectionAttemptTrigger,
    runID: UUID
  ) async {
    let endpoint: ControllerEndpoint
    do {
      endpoint = try ControllerEndpoint(address: address)
    } catch {
      guard isCurrent(runID) else {
        return
      }
      await diagnosticLogger.record(
        .connectionStopped(reason: .classify(error))
      )
      connectionState = .disconnected
      message = error.localizedDescription
      return
    }

    var backoff = ReconnectBackoff()
    var isFirstAttempt = true
    var attemptNumber = 1

    while !Task.isCancelled, isCurrent(runID) {
      connectionState = isFirstAttempt ? .connecting : .reconnecting
      if !isFirstAttempt {
        message = "正在重新连接 Mihomo 服务…"
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
        if isFirstAttempt, initialTrigger == .userRequest {
          try await secretStore.saveSecret(secret, reason: .connectionValidated)
        }
        guard isCurrent(runID) else {
          return
        }

        userDefaults.set(endpoint.baseURL.absoluteString, forKey: Self.addressDefaultsKey)
        self.address = endpoint.baseURL.absoluteString
        mihomoVersion = version.version
        measurementSession.configure(
          catalog: ProxyCatalog(typesByName: proxies.proxies.mapValues(\.type))
        )
        resetLiveData()
        message = "Mihomo 服务已验证，等待实时数据…"
        let streamID = livenessWatchdog.beginStream { [weak self] event in
          await self?.handleLivenessEvent(event, runID: runID)
        }

        try await collector.collect(
          endpoint: endpoint,
          secret: secret
        ) { [weak self] snapshot in
          await self?.consume(
            snapshot,
            endpoint: endpoint,
            secret: secret,
            runID: runID,
            streamID: streamID
          )
        }
        throw ConnectionStreamError.closed
      } catch is CancellationError {
        if isCurrent(runID) {
          _ = livenessWatchdog.finishStream()
        }
        return
      } catch MihomoControllerError.authenticationFailed {
        guard isCurrent(runID) else {
          return
        }
        await diagnosticLogger.record(
          .connectionStopped(reason: .authenticationFailed)
        )
        stopForTerminalError(
          state: .authenticationFailed,
          message: MihomoControllerError.authenticationFailed.localizedDescription
        )
        return
      } catch MihomoControllerError.unsupportedResponse {
        guard isCurrent(runID) else {
          return
        }
        await diagnosticLogger.record(
          .connectionStopped(reason: .unsupportedResponse)
        )
        stopForTerminalError(
          state: .unsupported,
          message: MihomoControllerError.unsupportedResponse.localizedDescription
        )
        return
      } catch ConnectionStreamError.unsupportedResponse {
        guard isCurrent(runID) else {
          return
        }
        await diagnosticLogger.record(
          .connectionStopped(reason: .unsupportedResponse)
        )
        stopForTerminalError(
          state: .unsupported,
          message: ConnectionStreamError.unsupportedResponse.localizedDescription
        )
        return
      } catch let error as KeychainSecretStoreError {
        guard isCurrent(runID) else {
          return
        }
        await diagnosticLogger.record(
          .connectionStopped(reason: .classify(error))
        )
        stopForTerminalError(state: .disconnected, message: error.localizedDescription)
        return
      } catch {
        guard isCurrent(runID), !Task.isCancelled else {
          return
        }

        let streamCompletion = livenessWatchdog.finishStream()
        if streamCompletion.shouldResetBackoff {
          backoff.reset()
        }
        let reason =
          streamCompletion.forcedReason
          ?? ConnectionDiagnosticReason.classify(error)
        resetLiveData()
        connectionState = .reconnecting
        if reason == .dataStale {
          message = "实时数据持续超时，等待重新连接。"
        } else {
          message = error.localizedDescription
        }

        let delay = backoff.nextDelaySeconds()
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

  private func consume(
    _ snapshot: MihomoConnectionsSnapshot,
    endpoint: ControllerEndpoint,
    secret: String,
    runID: UUID,
    streamID: UUID
  ) async {
    guard isCurrent(runID), livenessWatchdog.acceptSnapshot(streamID: streamID),
      let result = measurementSession.consume(snapshot.trafficSnapshot)
    else {
      return
    }

    if result.requiresCatalogRefresh {
      refreshCatalogIfNeeded(
        endpoint: endpoint,
        secret: secret,
        runID: runID
      )
    }
    let connectionWasEstablished = connectionState == .connected
    connectionState = .connected
    message = "正在读取实时连接流量。"
    if !connectionWasEstablished {
      await diagnosticLogger.record(.connectionEstablished)
    }
    activeProxyLeaves = result.activeProxyLeaves

    guard let window = result.rateWindow else {
      return
    }

    rawRates = window.raw
    rates = window.smoothed
    coverage = window.coverage
  }

  private func refreshCatalogIfNeeded(
    endpoint: ControllerEndpoint,
    secret: String,
    runID: UUID
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
        guard isCurrent(runID), !Task.isCancelled else {
          catalogRefreshTask = nil
          return
        }
        measurementSession.updateCatalog(
          ProxyCatalog(typesByName: proxies.proxies.mapValues(\.type))
        )
      } catch {
        // 刷新失败不打断当前流量流，后续未知快照会再次尝试。
      }
      catalogRefreshTask = nil
    }
  }

  private func handleLivenessEvent(
    _ event: ConnectionLivenessWatchdog.Event,
    runID: UUID
  ) async {
    guard isCurrent(runID) else {
      return
    }

    switch event {
    case .stale(let streamID, let lastSnapshotAgeMilliseconds):
      guard livenessWatchdog.isCurrentStream(streamID) else {
        return
      }
      connectionState = .stale
      message = "超过 2 秒未收到实时数据；持续 5 秒将重新连接。"
      resetLiveData()
      await diagnosticLogger.record(
        .connectionDataStale(
          timeoutSeconds: livenessWatchdog.policy.staleTimeoutSeconds,
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
      connectionState = .reconnecting
      message = "实时数据持续超时，准备重新连接。"
      await diagnosticLogger.record(
        .connectionCancellationRequested(
          source: .staleWatchdog,
          lastSnapshotAgeMilliseconds: lastSnapshotAgeMilliseconds
        )
      )
      await collector.cancel()
    }
  }

  private func stopForTerminalError(
    state: MonitorConnectionState,
    message: String
  ) {
    livenessWatchdog.cancel()
    resetLiveData()
    connectionState = state
    self.message = message
  }

  private func resetLiveData() {
    rates = .zero
    rawRates = .zero
    coverage = nil
    activeProxyLeaves = []
  }

  private func isCurrent(_ runID: UUID) -> Bool {
    self.runID == runID
  }

  private var isConnectionActive: Bool {
    switch connectionState {
    case .connecting, .connected, .stale, .reconnecting:
      true
    case .disconnected, .authenticationFailed, .unsupported:
      false
    }
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
