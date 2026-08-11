enum SharedCoreRuntimeProbe {
  static func run(
    abiVersion: () -> UInt32 = { MihomoMeterSharedCoreAdapter.abiVersion },
    scaleTraffic: (UInt64) throws -> SharedTrafficScale =
      MihomoMeterSharedCoreAdapter.scaleTraffic(bytes:)
  ) -> SharedCoreRuntimeStatus {
    guard abiVersion() == 1 else {
      return .abiMismatch
    }

    do {
      let result = try scaleTraffic(1_500)
      guard result.value == 1.5,
        result.unit == .kilobytes,
        result.decimalPlaces == 2
      else {
        return .unexpectedResult
      }
      return .ready
    } catch let error as SharedCoreAdapterError {
      switch error {
      case .nativeCallFailed:
        return .nativeCallFailed
      case .unsupportedABIVersion:
        return .abiMismatch
      case .unsupportedTrafficUnit:
        return .unsupportedTrafficUnit
      }
    } catch {
      return .unknownFailure
    }
  }
}
