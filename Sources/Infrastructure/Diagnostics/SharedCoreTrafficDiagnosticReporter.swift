enum SharedCoreTrafficDiagnosticReporter {
  static func reportShadow(_ observation: SharedCoreTrafficShadowObservation) {
    Task {
      await AppDiagnosticLogger.shared.record(.sharedCoreTrafficShadow(observation))
    }
  }

  static func reportRoute(_ observation: SharedCoreTrafficRouteObservation) {
    Task {
      await AppDiagnosticLogger.shared.record(.sharedCoreTrafficRoute(observation))
    }
  }
}
