import os

enum SharedCoreTrafficShadowDiagnosticReporter {
  private static let reportedObservations = OSAllocatedUnfairLock(
    initialState: Set<SharedCoreTrafficShadowObservation>()
  )

  static func report(_ observation: SharedCoreTrafficShadowObservation) {
    guard observation.status != .matched else {
      return
    }
    let shouldReport = reportedObservations.withLock { observations in
      observations.insert(observation).inserted
    }
    guard shouldReport else {
      return
    }

    Task {
      await AppDiagnosticLogger.shared.record(.sharedCoreTrafficShadow(observation))
    }
  }
}
