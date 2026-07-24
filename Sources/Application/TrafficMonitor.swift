import Combine
import Foundation

@MainActor
final class TrafficMonitor: ObservableObject {
  @Published var address: String
  @Published var secret: String
  @Published private var state = TrafficMonitorState()

  private let configurationStore: ControllerConfigurationStore
  private let coordinator: TrafficMonitoringCoordinator

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

  var activeProxyLeaves: [String] {
    state.activeProxyLeaves
  }

  var mihomoVersion: String? {
    state.mihomoVersion
  }

  var message: String {
    state.message
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
    userDefaults: UserDefaults = .standard
  ) {
    let configurationStore = ControllerConfigurationStore(
      secretStore: secretStore,
      userDefaults: userDefaults
    )
    self.configurationStore = configurationStore
    address = configurationStore.storedAddress
    secret = ""
    coordinator = TrafficMonitoringCoordinator(
      client: client,
      collector: collector,
      configurationStore: configurationStore,
      diagnosticLogger: diagnosticLogger,
      livenessPolicy: livenessPolicy
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
  }

  func stopForApplicationTermination() {
    stopConnection(source: .applicationTermination)
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
    if case .validated(let address, _) = event {
      self.address = address
    }
    state = TrafficMonitorReducer.reduce(state, event: event)
  }
}
