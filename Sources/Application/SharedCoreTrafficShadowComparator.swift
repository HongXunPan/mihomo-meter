enum SharedCoreTrafficShadowComparator {
  static func compare(
    bytes: UInt64,
    nativeText: String,
    format: SharedCoreTrafficFormat,
    scaleTraffic: (UInt64) throws -> SharedTrafficScale =
      MihomoMeterSharedCoreAdapter.scaleTraffic(bytes:)
  ) -> SharedCoreTrafficShadowStatus {
    do {
      let scale = try scaleTraffic(bytes)
      let sharedText = try SharedCoreTrafficDisplayFormatter.string(
        from: scale,
        format: format
      )
      return sharedText == nativeText ? .matched : .mismatch
    } catch let error as SharedCoreAdapterError {
      switch error {
      case .nativeCallFailed:
        return .nativeCallFailed
      case .unsupportedABIVersion:
        return .abiMismatch
      case .unsupportedTrafficUnit:
        return .unsupportedTrafficUnit
      }
    } catch is SharedCoreTrafficDisplayFormatter.Error {
      return .unexpectedResult
    } catch {
      return .unknownFailure
    }
  }
}
