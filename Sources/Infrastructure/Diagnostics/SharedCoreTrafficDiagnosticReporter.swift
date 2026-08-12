enum SharedCoreTrafficDiagnosticReporter {
  static func reportProxyTypeShadow(_ observation: SharedCoreProxyTypeShadowObservation) {
    Task {
      await AppDiagnosticLogger.shared.record(.sharedCoreProxyTypeShadow(observation))
    }
  }

  static func reportProxyTypeRoute(_ observation: SharedCoreProxyTypeRouteObservation) {
    Task {
      await AppDiagnosticLogger.shared.record(.sharedCoreProxyTypeRoute(observation))
    }
  }

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
