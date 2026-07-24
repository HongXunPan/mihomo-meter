import Foundation

@MainActor
final class ConnectionLivenessWatchdog {
  struct Policy: Equatable, Sendable {
    static let production = Policy(
      staleAfterNanoseconds: 2_000_000_000,
      reconnectAfterNanoseconds: 5_000_000_000,
      backoffResetAfterNanoseconds: 30_000_000_000
    )

    let staleAfterNanoseconds: UInt64
    let reconnectAfterNanoseconds: UInt64
    let backoffResetAfterNanoseconds: UInt64

    init(
      staleAfterNanoseconds: UInt64,
      reconnectAfterNanoseconds: UInt64,
      backoffResetAfterNanoseconds: UInt64
    ) {
      precondition(staleAfterNanoseconds > 0)
      precondition(reconnectAfterNanoseconds > staleAfterNanoseconds)
      precondition(backoffResetAfterNanoseconds > 0)
      self.staleAfterNanoseconds = staleAfterNanoseconds
      self.reconnectAfterNanoseconds = reconnectAfterNanoseconds
      self.backoffResetAfterNanoseconds = backoffResetAfterNanoseconds
    }

    var staleTimeoutSeconds: Int {
      Int(staleAfterNanoseconds / 1_000_000_000)
    }

    var reconnectTimeoutSeconds: Int {
      Int(reconnectAfterNanoseconds / 1_000_000_000)
    }
  }

  enum Event: Equatable, Sendable {
    case stale(
      streamID: UUID,
      lastSnapshotAgeMilliseconds: Int
    )
    case reconnectRequired(
      streamID: UUID,
      lastSnapshotAgeMilliseconds: Int
    )
  }

  struct StreamCompletion: Equatable, Sendable {
    let forcedReason: ConnectionDiagnosticReason?
    let shouldResetBackoff: Bool
  }

  typealias EventHandler = @MainActor @Sendable (Event) async -> Void

  let policy: Policy

  private let clock = ContinuousClock()
  private var watchdogTask: Task<Void, Never>?
  private var streamID: UUID?
  private var lastSnapshotAt: ContinuousClock.Instant?
  private var connectedAt: ContinuousClock.Instant?
  private var forcedTerminationReason: ConnectionDiagnosticReason?
  private var eventHandler: EventHandler?

  init(policy: Policy = .production) {
    self.policy = policy
  }

  func beginStream(
    eventHandler: @escaping EventHandler
  ) -> UUID {
    cancel()

    let streamID = UUID()
    self.streamID = streamID
    lastSnapshotAt = clock.now
    self.eventHandler = eventHandler
    armWatchdog(for: streamID)
    return streamID
  }

  func acceptSnapshot(streamID: UUID) -> Bool {
    guard self.streamID == streamID else {
      return false
    }

    let now = clock.now
    lastSnapshotAt = now
    if connectedAt == nil {
      connectedAt = now
    }
    armWatchdog(for: streamID)
    return true
  }

  func isCurrentStream(_ streamID: UUID) -> Bool {
    self.streamID == streamID
  }

  var currentSnapshotAgeMilliseconds: Int? {
    guard streamID != nil, lastSnapshotAt != nil else {
      return nil
    }
    return lastSnapshotAgeMilliseconds
  }

  func requestTermination(
    streamID: UUID,
    reason: ConnectionDiagnosticReason
  ) -> Bool {
    guard self.streamID == streamID else {
      return false
    }

    self.streamID = nil
    forcedTerminationReason = reason
    watchdogTask?.cancel()
    watchdogTask = nil
    return true
  }

  func finishStream() -> StreamCompletion {
    let completion = StreamCompletion(
      forcedReason: forcedTerminationReason,
      shouldResetBackoff: hasStableConnection
    )
    cancel()
    return completion
  }

  func cancel() {
    watchdogTask?.cancel()
    watchdogTask = nil
    streamID = nil
    lastSnapshotAt = nil
    connectedAt = nil
    forcedTerminationReason = nil
    eventHandler = nil
  }

  private func armWatchdog(for streamID: UUID) {
    watchdogTask?.cancel()
    watchdogTask = Task { [weak self] in
      guard let self else {
        return
      }

      do {
        try await Task.sleep(
          nanoseconds: policy.staleAfterNanoseconds
        )
      } catch {
        return
      }

      guard self.streamID == streamID, let eventHandler else {
        return
      }
      await eventHandler(
        .stale(
          streamID: streamID,
          lastSnapshotAgeMilliseconds: lastSnapshotAgeMilliseconds
        )
      )

      do {
        try await Task.sleep(
          nanoseconds: policy.reconnectAfterNanoseconds
            - policy.staleAfterNanoseconds
        )
      } catch {
        return
      }

      guard self.streamID == streamID, let eventHandler = self.eventHandler else {
        return
      }
      await eventHandler(
        .reconnectRequired(
          streamID: streamID,
          lastSnapshotAgeMilliseconds: lastSnapshotAgeMilliseconds
        )
      )
    }
  }

  private var lastSnapshotAgeMilliseconds: Int {
    guard let lastSnapshotAt else {
      return 0
    }
    return Self.milliseconds(from: lastSnapshotAt.duration(to: clock.now))
  }

  private var hasStableConnection: Bool {
    guard let connectedAt else {
      return false
    }
    let elapsedSeconds = Self.seconds(from: connectedAt.duration(to: clock.now))
    let thresholdSeconds =
      Double(policy.backoffResetAfterNanoseconds) / 1_000_000_000
    return elapsedSeconds >= thresholdSeconds
  }

  private static func milliseconds(from duration: Duration) -> Int {
    let components = duration.components
    let milliseconds =
      components.seconds * 1_000
      + components.attoseconds / 1_000_000_000_000_000
    return max(Int(milliseconds), 0)
  }

  private static func seconds(from duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds)
      + Double(components.attoseconds) / 1_000_000_000_000_000_000
  }
}
