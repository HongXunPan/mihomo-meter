import Combine
import Foundation

@MainActor
final class TrafficMonitor: ObservableObject {
  @Published var address: String
  @Published var secret: String
  @Published private var state = TrafficMonitorState()

  private let configurationStore: ControllerConfigurationStore
  private let coordinator: TrafficMonitoringCoordinator
  private let statisticsRecorder: any TrafficStatisticsRecording
  private let connectionAnalyticsRecorder: any ConnectionAnalyticsRecording
  private let runtimeQuotaLifecycle: any RuntimeQuotaTrackingLifecycle
  private let profileQuotaLifecycle: any ProfileQuotaTrackingLifecycle

  var connectionState: MonitorConnectionState {
    state.connectionState
  }

  var rates: CategorizedTrafficRates {
    state.rates
  }

  var rawRates: CategorizedTrafficRates {
    state.rawRates
  }

  var coverage: Double? {
    state.coverage
  }

  var attributionCoverage: ConnectionAttributionCoverage {
    state.attributionCoverage
  }

  var liveProxyConnections: [LiveTrafficConnection] {
    state.liveProxyConnections
  }

  var liveDirectConnections: [LiveTrafficConnection] {
    state.liveDirectConnections
  }

  var activeProxyLeaves: [String] {
    state.activeProxyLeaves
  }

  var activeRuleTypes: [String] {
    state.activeRuleTypes
  }

  var runtimeConfiguration: MihomoRuntimeConfiguration? {
    state.runtimeConfiguration
  }

  var mihomoVersion: String? {
    state.mihomoVersion
  }

  var lastObservedAt: Date? {
    state.lastObservedAt
  }

  var message: String {
    state.message
  }

  var hasValidatedControllerConfiguration: Bool {
    configurationStore.hasValidatedConfiguration
  }

  var connectionStatePublisher: AnyPublisher<MonitorConnectionState, Never> {
    $state
      .map(\.connectionState)
      .removeDuplicates()
      .eraseToAnyPublisher()
  }

  var statusItemPublisher: AnyPublisher<TrafficStatusItemSnapshot, Never> {
    $state
      .map {
        TrafficStatusItemSnapshot(
          rate: $0.rates.proxy,
          connectionState: $0.connectionState
        )
      }
      .removeDuplicates()
      .eraseToAnyPublisher()
  }

  init(
    client: any MihomoControllerServing = MihomoControllerClient(),
    collector: any ConnectionSnapshotCollecting = ConnectionStreamCollector(),
    secretStore: any ControllerSecretStoring = KeychainSecretStore(),
    diagnosticLogger: any AppDiagnosticLogging = NoOpAppDiagnosticLogger.shared,
    livenessPolicy: ConnectionLivenessWatchdog.Policy = .production,
    statisticsRecorder: any TrafficStatisticsRecording = NoOpTrafficStatisticsRecorder.shared,
    connectionAnalyticsRecorder: any ConnectionAnalyticsRecording =
      NoOpConnectionAnalyticsRecorder.shared,
    runtimeQuotaLifecycle: any RuntimeQuotaTrackingLifecycle =
      NoOpRuntimeQuotaTrackingLifecycle.shared,
    profileQuotaLifecycle: any ProfileQuotaTrackingLifecycle =
      NoOpProfileQuotaTrackingLifecycle.shared,
    userDefaults: UserDefaults = .standard
  ) {
    let configurationStore = ControllerConfigurationStore(
      secretStore: secretStore,
      userDefaults: userDefaults
    )
    self.configurationStore = configurationStore
    self.statisticsRecorder = statisticsRecorder
    self.connectionAnalyticsRecorder = connectionAnalyticsRecorder
    self.runtimeQuotaLifecycle = runtimeQuotaLifecycle
    self.profileQuotaLifecycle = profileQuotaLifecycle
    address = configurationStore.storedAddress
    secret = ""
    coordinator = TrafficMonitoringCoordinator(
      client: client,
      collector: collector,
      configurationStore: configurationStore,
      diagnosticLogger: diagnosticLogger,
      livenessPolicy: livenessPolicy,
      statisticsRecorder: statisticsRecorder,
      connectionAnalyticsRecorder: connectionAnalyticsRecorder
    )
  }

  func start() {
    Task { [weak self] in
      guard let self else {
        return
      }

      do {
        let configuration = try await configurationStore.loadStartupConfiguration()
        address = configuration.address
        secret = configuration.secret
        if !configuration.address.isEmpty {
          startConnection(trigger: .applicationStartup)
        }
      } catch {
        state = TrafficMonitorReducer.reduce(
          state,
          event: .terminal(
            state: .disconnected,
            message: error.localizedDescription
          )
        )
      }
    }
  }

  func connect() {
    startConnection(trigger: .userRequest)
  }

  func reconnectNow() {
    startConnection(trigger: .immediateRetry)
  }

  func disconnect() {
    stopConnection(source: .userDisconnect)
    Task {
      await statisticsRecorder.interruptMonitoring(at: Date())
      await connectionAnalyticsRecorder.flushPending()
    }
  }

  func stopForApplicationTermination() async {
    await coordinator.stopAndWait(source: .applicationTermination) { [weak self] event in
      self?.apply(event)
    }
    await connectionAnalyticsRecorder.flushPending()
  }

  private func startConnection(trigger: ConnectionAttemptTrigger) {
    coordinator.start(
      address: address,
      secret: secret,
      trigger: trigger
    ) { [weak self] event in
      self?.apply(event)
    }
  }

  private func stopConnection(source: ConnectionCancellationSource) {
    coordinator.stop(source: source) { [weak self] event in
      self?.apply(event)
    }
  }

  private func apply(_ event: TrafficMonitoringCoordinator.Event) {
    if case .validated(let address, _, _) = event {
      self.address = address
    }
    updateQuotaLifecycles(for: event)
    state = TrafficMonitorReducer.reduce(state, event: event)
  }

  private func updateQuotaLifecycles(
    for event: TrafficMonitoringCoordinator.Event
  ) {
    switch event {
    case .validated(let address, _, let runtimeConfiguration):
      guard let endpoint = try? ControllerEndpoint(address: address) else {
        runtimeQuotaLifecycle.controllerUnavailable()
        profileQuotaLifecycle.controllerUnavailable()
        return
      }
      runtimeQuotaLifecycle.controllerValidated(endpoint: endpoint, secret: secret)
      if let runtimeConfiguration {
        profileQuotaLifecycle.controllerValidated(
          endpoint: endpoint,
          runtimeConfiguration: runtimeConfiguration
        )
      } else {
        profileQuotaLifecycle.controllerUnavailable()
      }
    case .validating, .retrying, .reconnectRequired, .reconnectScheduled, .terminal, .stopped:
      runtimeQuotaLifecycle.controllerUnavailable()
      profileQuotaLifecycle.controllerUnavailable()
    case .measurement, .dataStale:
      break
    }
  }
}
