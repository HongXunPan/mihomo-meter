enum SharedCoreProxyTypeRouteSource: String, Hashable, Sendable {
  case sharedPrimary = "shared_primary"
  case nativeFallback = "native_fallback"
}

enum SharedCoreProxyTypeShadowSource: String, Hashable, Sendable {
  case sharedShadow = "shared_shadow"
  case nativeFallback = "native_fallback"
}

enum SharedCoreProxyTypeRouteStatus: String, Hashable, Sendable {
  case matched
  case unrecognized
  case abiMismatch = "abi_mismatch"
  case nativeCallFailed = "native_call_failed"
  case unsupportedInput = "unsupported_input"
  case inputTooLong = "input_too_long"
  case unexpectedResult = "unexpected_result"
  case mismatch
  case unknownFailure = "unknown_failure"
}

struct SharedCoreProxyTypeRouteObservation: Equatable, Hashable, Sendable {
  let source: SharedCoreProxyTypeRouteSource
  let status: SharedCoreProxyTypeRouteStatus
}

struct SharedCoreProxyTypeShadowObservation: Equatable, Hashable, Sendable {
  let source: SharedCoreProxyTypeShadowSource
  let status: SharedCoreProxyTypeRouteStatus
}

struct SharedCoreProxyTypeRouteObservationGate: Sendable {
  private var reportedObservations: Set<SharedCoreProxyTypeRouteObservation> = []

  mutating func shouldReport(_ observation: SharedCoreProxyTypeRouteObservation) -> Bool {
    reportedObservations.insert(observation).inserted
  }

  mutating func reset() {
    reportedObservations = []
  }
}

struct SharedCoreProxyTypeShadowObservationGate: Sendable {
  private var reportedObservations: Set<SharedCoreProxyTypeShadowObservation> = []

  mutating func shouldReport(_ observation: SharedCoreProxyTypeShadowObservation) -> Bool {
    reportedObservations.insert(observation).inserted
  }

  mutating func reset() {
    reportedObservations = []
  }
}
