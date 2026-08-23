import AppKit
@preconcurrency import Network

@MainActor
final class SystemEnvironmentMonitor {
  typealias EventHandler = @MainActor (SystemEnvironmentBlocker, Bool) -> Void

  private let workspace: NSWorkspace
  private let networkQueue: DispatchQueue
  private var workspaceObservers: [NSObjectProtocol] = []
  private var pathMonitor: NWPathMonitor?
  private var generation = UUID()
  private var eventHandler: EventHandler?

  init(
    workspace: NSWorkspace = .shared,
    networkQueue: DispatchQueue = DispatchQueue(
      label: "com.HongXunPan.MihomoMeter.system-environment"
    )
  ) {
    self.workspace = workspace
    self.networkQueue = networkQueue
  }

  deinit {
    pathMonitor?.cancel()
  }

  func start(eventHandler: @escaping EventHandler) {
    stop()
    self.eventHandler = eventHandler
    let generation = UUID()
    self.generation = generation
    observeWorkspace()
    observeNetwork(generation: generation)
  }

  func stop() {
    generation = UUID()
    let center = workspace.notificationCenter
    workspaceObservers.forEach(center.removeObserver)
    workspaceObservers.removeAll()
    pathMonitor?.cancel()
    pathMonitor = nil
    eventHandler = nil
  }

  private func observeWorkspace() {
    observe(NSWorkspace.willSleepNotification, blocker: .sleep, isBlocked: true)
    observe(NSWorkspace.didWakeNotification, blocker: .sleep, isBlocked: false)
    observe(
      NSWorkspace.sessionDidResignActiveNotification,
      blocker: .inactiveSession,
      isBlocked: true
    )
    observe(
      NSWorkspace.sessionDidBecomeActiveNotification,
      blocker: .inactiveSession,
      isBlocked: false
    )
  }

  private func observe(
    _ name: Notification.Name,
    blocker: SystemEnvironmentBlocker,
    isBlocked: Bool
  ) {
    let observer = workspace.notificationCenter.addObserver(
      forName: name,
      object: workspace,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.eventHandler?(blocker, isBlocked)
      }
    }
    workspaceObservers.append(observer)
  }

  private func observeNetwork(generation: UUID) {
    let monitor = NWPathMonitor()
    pathMonitor = monitor
    monitor.pathUpdateHandler = { [weak self] path in
      let isBlocked = path.status != .satisfied
      Task { @MainActor [weak self] in
        guard let self, self.generation == generation else {
          return
        }
        eventHandler?(.networkUnavailable, isBlocked)
      }
    }
    monitor.start(queue: networkQueue)
  }
}
