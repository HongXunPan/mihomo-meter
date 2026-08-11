enum SharedCoreTrafficShadowDiagnosticReporter {
  static func report(_ observation: SharedCoreTrafficShadowObservation) {
    Task {
      await AppDiagnosticLogger.shared.record(.sharedCoreTrafficShadow(observation))
    }
  }
}
