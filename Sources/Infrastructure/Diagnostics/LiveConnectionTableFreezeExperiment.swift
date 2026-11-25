import Foundation

enum LiveConnectionTableFreezePhase: String, Equatable, Sendable {
  case disabled
  case baseline
  case frozen
  case resumed
}

@MainActor
final class LiveConnectionTableFreezeExperiment {
  static let enabledKey = "MIHOMO_METER_DIAG_FREEZE_LIVE_TABLE"
  #if DEBUG
    static let shared: LiveConnectionTableFreezeExperiment = {
      let variables = ProcessInfo.processInfo.environment
      return LiveConnectionTableFreezeExperiment(
        isEnabled: variables[ProcessPerformanceDiagnostics.enabledKey] == "1"
          && variables[enabledKey] == "1"
      )
    }()
  #else
    static let shared = LiveConnectionTableFreezeExperiment(isEnabled: false)
  #endif

  private(set) var phase: LiveConnectionTableFreezePhase

  init(isEnabled: Bool) {
    phase = isEnabled ? .baseline : .disabled
  }

  func shouldSkipUpdate(hasExistingRows: Bool) -> Bool {
    phase == .frozen && hasExistingRows
  }

  func completeInterval(_ metrics: LiveConnectionTableIntervalMetrics)
    -> LiveConnectionTableFreezePhase
  {
    let completedPhase = phase
    switch phase {
    case .baseline:
      if metrics.isMountedAtEnd, metrics.mountCount == 0, metrics.unmountCount == 0,
        metrics.updateCount > 0
      {
        phase = .frozen
      }
    case .frozen:
      phase = .resumed
    case .disabled, .resumed:
      break
    }
    return completedPhase
  }
}
