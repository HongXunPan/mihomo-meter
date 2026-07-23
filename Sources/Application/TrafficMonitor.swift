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
  @Published private(set) var message = "请输入本机 Controller 地址和 Secret。"

  private static let addressDefaultsKey = "controllerAddress"
  private static let staleTimeoutNanoseconds: UInt64 = 2_000_000_000

  private let client: any MihomoControllerServing
  private let collector: any ConnectionSnapshotCollecting
  private let secretStore: any ControllerSecretStoring
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
    userDefaults: UserDefaults = .standard
  ) {
    self.client = client
    self.collector = collector
    self.secretStore = secretStore
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
        secret = try await secretStore.loadSecret() ?? ""
        if !savedAddress.isEmpty {
          connect()
        }
      } catch {
        connectionState = .disconnected
        message = error.localizedDescription
      }
    }
  }

  func connect() {
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
    message = "正在验证 Controller…"

    connectionTask = Task { [weak self] in
      guard let self else {
        return
      }

      await collector.cancel()
      await runConnectionLoop(
        address: requestedAddress,
        secret: requestedSecret,
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
    runID: UUID
  ) async {
    let endpoint: ControllerEndpoint
    do {
      endpoint = try ControllerEndpoint(address: address)
    } catch {
      guard isCurrent(runID) else {
        return
      }
      connectionState = .disconnected
      message = error.localizedDescription
      return
    }

    var backoff = ReconnectBackoff()
    var isFirstAttempt = true

    while !Task.isCancelled, isCurrent(runID) {
      connectionState = isFirstAttempt ? .connecting : .reconnecting
      if !isFirstAttempt {
        message = "正在重新连接 Controller…"
      }

      do {
        let version = try await client.fetchVersion(endpoint: endpoint, secret: secret)
        let proxies = try await client.fetchProxies(endpoint: endpoint, secret: secret)
        try await secretStore.saveSecret(secret)
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
        message = "Controller 已验证，等待连接快照…"
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
        stopForTerminalError(
          state: .authenticationFailed,
          message: MihomoControllerError.authenticationFailed.localizedDescription
        )
        return
      } catch MihomoControllerError.unsupportedResponse {
        guard isCurrent(runID) else {
          return
        }
        stopForTerminalError(
          state: .unsupported,
          message: MihomoControllerError.unsupportedResponse.localizedDescription
        )
        return
      } catch ConnectionStreamError.unsupportedResponse {
        guard isCurrent(runID) else {
          return
        }
        stopForTerminalError(
          state: .unsupported,
          message: ConnectionStreamError.unsupportedResponse.localizedDescription
        )
        return
      } catch let error as KeychainSecretStoreError {
        guard isCurrent(runID) else {
          return
        }
        stopForTerminalError(state: .disconnected, message: error.localizedDescription)
        return
      } catch {
        guard isCurrent(runID), !Task.isCancelled else {
          return
        }

        staleTask?.cancel()
        resetLiveData()
        if connectionState != .stale {
          connectionState = .reconnecting
          message = error.localizedDescription
        }

        let delay = backoff.nextDelaySeconds()
        do {
          try await Task.sleep(nanoseconds: delay * 1_000_000_000)
        } catch {
          return
        }
        isFirstAttempt = false
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
    connectionState = .connected
    message = "正在读取实时连接流量。"
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
