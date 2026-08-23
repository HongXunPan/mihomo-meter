import Foundation

@MainActor
final class SustainedDisconnectionNotificationTracker {
  private let now: @MainActor () -> Date
  private let sustainedDisconnection: @MainActor () -> Void
  private let connectionRecovered: @MainActor () -> Void

  private var disconnectedSince: Date?
  private var isTracking = false
  private var timerTask: Task<Void, Never>?

  init(
    now: @escaping @MainActor () -> Date,
    sustainedDisconnection: @escaping @MainActor () -> Void,
    connectionRecovered: @escaping @MainActor () -> Void
  ) {
    self.now = now
    self.sustainedDisconnection = sustainedDisconnection
    self.connectionRecovered = connectionRecovered
  }

  func update(
    state: MonitorConnectionState,
    expected: Bool,
    hasValidatedConfiguration: Bool
  ) {
    let shouldTrack = expected && hasValidatedConfiguration && state != .connected
    guard shouldTrack else {
      reset()
      return
    }

    isTracking = true
    if disconnectedSince == nil {
      disconnectedSince = now()
    }
    scheduleEvaluation()
  }

  func evaluateNow() {
    guard
      isTracking,
      ConnectionSystemNotificationPolicy.shouldNotify(
        disconnectedSince: disconnectedSince,
        at: now()
      )
    else {
      return
    }
    sustainedDisconnection()
  }

  func stop() {
    timerTask?.cancel()
    timerTask = nil
    disconnectedSince = nil
    isTracking = false
  }

  private func scheduleEvaluation() {
    timerTask?.cancel()
    guard let disconnectedSince else {
      return
    }
    let elapsed = now().timeIntervalSince(disconnectedSince)
    let delay = max(
      0,
      ConnectionSystemNotificationPolicy.sustainedDisconnectionInterval - elapsed
    )
    timerTask = Task { [weak self] in
      if delay > 0 {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
      guard !Task.isCancelled else {
        return
      }
      self?.evaluateNow()
    }
  }

  private func reset() {
    let wasTracking = isTracking
    stop()
    if wasTracking {
      connectionRecovered()
    }
  }
}
