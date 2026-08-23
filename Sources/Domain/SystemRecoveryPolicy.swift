import Foundation

enum SystemEnvironmentBlocker: Hashable, Sendable {
  case sleep
  case inactiveSession
  case networkUnavailable
}

enum SystemRecoveryAction: Equatable, Sendable {
  case pause
  case resume
}

struct SystemRecoveryPolicy: Sendable {
  private var blockers: Set<SystemEnvironmentBlocker> = []

  var isAvailable: Bool {
    blockers.isEmpty
  }

  mutating func update(
    _ blocker: SystemEnvironmentBlocker,
    isBlocked: Bool
  ) -> SystemRecoveryAction? {
    let wasAvailable = isAvailable
    if isBlocked {
      blockers.insert(blocker)
    } else {
      blockers.remove(blocker)
    }

    guard wasAvailable != isAvailable else {
      return nil
    }
    return isAvailable ? .resume : .pause
  }
}
