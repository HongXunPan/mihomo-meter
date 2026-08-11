enum SharedCoreTrafficFormat: String, Hashable, Sendable {
  case byteCount = "byte_count"
  case rate
  case compactRate = "compact_rate"
}

enum SharedCoreTrafficShadowStatus: String, Hashable, Sendable {
  case matched
  case abiMismatch = "abi_mismatch"
  case nativeCallFailed = "native_call_failed"
  case unsupportedTrafficUnit = "unsupported_traffic_unit"
  case unexpectedResult = "unexpected_result"
  case mismatch
  case unknownFailure = "unknown_failure"
}

struct SharedCoreTrafficShadowObservation: Hashable, Sendable {
  let format: SharedCoreTrafficFormat
  let status: SharedCoreTrafficShadowStatus
}

struct SharedCoreTrafficShadowObservationGate: Sendable {
  private var reportedObservations: Set<SharedCoreTrafficShadowObservation> = []

  mutating func shouldReport(_ observation: SharedCoreTrafficShadowObservation) -> Bool {
    reportedObservations.insert(observation).inserted
  }

  mutating func reset() {
    reportedObservations.removeAll(keepingCapacity: true)
  }
}
