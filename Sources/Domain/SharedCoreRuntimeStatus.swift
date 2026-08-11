enum SharedCoreRuntimeStatus: String, Equatable, Sendable {
  case ready
  case abiMismatch = "abi_mismatch"
  case nativeCallFailed = "native_call_failed"
  case unsupportedTrafficUnit = "unsupported_traffic_unit"
  case unexpectedResult = "unexpected_result"
  case unknownFailure = "unknown_failure"
}
