import Foundation

@MainActor
final class SystemRecoveryController {
  private let monitor: TrafficMonitor
  private let environmentMonitor: SystemEnvironmentMonitor
  private var policy = SystemRecoveryPolicy()

  init(
    monitor: TrafficMonitor,
    environmentMonitor: SystemEnvironmentMonitor = SystemEnvironmentMonitor()
  ) {
    self.monitor = monitor
    self.environmentMonitor = environmentMonitor
  }

  func start(initialSessionIsInactive: Bool = false) {
    if initialSessionIsInactive,
      let action = policy.update(.inactiveSession, isBlocked: true)
    {
      monitor.setSystemEnvironmentAvailable(action == .resume)
    }
    environmentMonitor.start { [weak self] blocker, isBlocked in
      self?.handle(blocker, isBlocked: isBlocked)
    }
  }

  func stop() {
    environmentMonitor.stop()
  }

  private func handle(
    _ blocker: SystemEnvironmentBlocker,
    isBlocked: Bool
  ) {
    guard let action = policy.update(blocker, isBlocked: isBlocked) else {
      return
    }
    monitor.setSystemEnvironmentAvailable(action == .resume)
  }
}
