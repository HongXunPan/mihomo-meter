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
  private static let staleTimeoutNanoseconds: UInt64 = 2_000_000_000

  private let client: any MihomoControllerServing
  private let collector: any ConnectionSnapshotCollecting
  private let secretStore: any ControllerSecretStoring
  private let diagnosticLogger: any AppDiagnosticLogging
  private let userDefaults: UserDefaults
  private let clock = ContinuousClock()

  private var connectionTask: Task<Void, Never>?
  private var staleTask: Task<Void, Never>?
  private var catalogRefreshTask: Task<Void, Never>?
  private var runID = UUID()
  private var classifier: ProxyClassifier?
  private var deltaTracker = ConnectionDeltaTracker()
  private var rateAggregator = TrafficRateAggregator()
  private var lastSnapshotInstant: ContinuousClock.Instant?

  init(
    client: any MihomoControllerServing = MihomoControllerClient(),
    collector: any ConnectionSnapshotCollecting = ConnectionStreamCollector(),
    secretStore: any ControllerSecretStoring = KeychainSecretStore(),
    diagnosticLogger: any AppDiagnosticLogging = NoOpAppDiagnosticLogger.shared,
    userDefaults: UserDefaults = .standard
  ) {
    self.client = client
    self.collector = collector
    self.secretStore = secretStore
    self.diagnosticLogger = diagnosticLogger
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
    let newRunID = UUID()
    runID = newRunID

    connectionTask?.cancel()
    staleTask?.cancel()
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
    runID = UUID()
    connectionTask?.cancel()
    connectionTask = nil
    staleTask?.cancel()
    staleTask = nil
    catalogRefreshTask?.cancel()
    catalogRefreshTask = nil
    Task { [collector] in
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
        try await secretStore.saveSecret(secret, reason: .connectionValidated)
        guard isCurrent(runID) else {
          return
        }

        userDefaults.set(endpoint.baseURL.absoluteString, forKey: Self.addressDefaultsKey)
        self.address = endpoint.baseURL.absoluteString
        mihomoVersion = version.version
        classifier = ProxyClassifier(
          catalog: ProxyCatalog(typesByName: proxies.proxies.mapValues(\.type))
        )
        resetMeasurementBaseline()
        message = "Mihomo 服务已验证，等待实时数据…"
        armStaleWatchdog(runID: runID)

        try await collector.collect(
          endpoint: endpoint,
          secret: secret
        ) { [weak self] snapshot in
          await self?.consume(
            snapshot,
            endpoint: endpoint,
            secret: secret,
            runID: runID
          )
        }
        throw ConnectionStreamError.closed
      } catch is CancellationError {
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

        let reason = ConnectionDiagnosticReason.classify(
          error,
          dataWasStale: connectionState == .stale
        )
        staleTask?.cancel()
        resetLiveData()
        if connectionState != .stale {
          connectionState = .reconnecting
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
    runID: UUID
  ) async {
    guard isCurrent(runID), let classifier else {
      return
    }

    let now = clock.now
    let elapsedSeconds = lastSnapshotInstant.map {
      Self.seconds(from: $0.duration(to: now))
    }
    lastSnapshotInstant = now
    armStaleWatchdog(runID: runID)
    refreshCatalogIfNeeded(
      for: snapshot,
      endpoint: endpoint,
      secret: secret,
      runID: runID
    )
    let connectionWasEstablished = connectionState == .connected
    connectionState = .connected
    message = "正在读取实时连接流量。"
    if !connectionWasEstablished {
      await diagnosticLogger.record(.connectionEstablished)
    }
    activeProxyLeaves = Array(
      Set(
        snapshot.connections.compactMap { connection in
          guard classifier.classify(chains: connection.chains).category == .proxy else {
            return nil
          }
          return connection.chains.first
        }
      )
    ).sorted()

    let result = deltaTracker.consume(snapshot.trafficSnapshot, classifier: classifier)
    guard case .delta(let report) = result, let elapsedSeconds,
      let window = rateAggregator.consume(report, elapsedSeconds: elapsedSeconds)
    else {
      return
    }

    rawRates = window.raw
    rates = window.smoothed
    coverage = window.coverage
  }

  private func refreshCatalogIfNeeded(
    for snapshot: MihomoConnectionsSnapshot,
    endpoint: ControllerEndpoint,
    secret: String,
    runID: UUID
  ) {
    guard catalogRefreshTask == nil, let currentClassifier = classifier,
      snapshot.connections.contains(where: {
        currentClassifier.classify(chains: $0.chains).unknownReason == .missingCatalogEntry
      })
    else {
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
        classifier = ProxyClassifier(
          catalog: ProxyCatalog(typesByName: proxies.proxies.mapValues(\.type))
        )
      } catch {
        // 刷新失败不打断当前流量流，后续未知快照会再次尝试。
      }
      catalogRefreshTask = nil
    }
  }

  private func armStaleWatchdog(runID: UUID) {
    staleTask?.cancel()
    staleTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: Self.staleTimeoutNanoseconds)
      } catch {
        return
      }

      guard let self, isCurrent(runID) else {
        return
      }
      connectionState = .stale
      message = "超过 2 秒未收到连接快照，准备重连。"
      resetLiveData()
      await diagnosticLogger.record(
        .connectionDataStale(timeoutSeconds: 2)
      )
      await collector.cancel()
    }
  }

  private func stopForTerminalError(
    state: MonitorConnectionState,
    message: String
  ) {
    staleTask?.cancel()
    resetLiveData()
    connectionState = state
    self.message = message
  }

  private func resetMeasurementBaseline() {
    deltaTracker.reset()
    rateAggregator.reset()
    lastSnapshotInstant = nil
    resetLiveData()
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

  private static func seconds(from duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds)
      + Double(components.attoseconds) / 1_000_000_000_000_000_000
  }
}
