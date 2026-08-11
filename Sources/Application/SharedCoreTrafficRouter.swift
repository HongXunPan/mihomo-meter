enum SharedCoreTrafficRouteSource: String, Hashable, Sendable {
  case sharedPrimary = "shared_primary"
  case nativeFallback = "native_fallback"
}

struct SharedCoreTrafficRouteResult: Equatable, Sendable {
  let text: String
  let source: SharedCoreTrafficRouteSource
  let status: SharedCoreTrafficShadowStatus
}

enum SharedCoreTrafficRouter {
  static func route(
    bytes: UInt64,
    nativeText: String,
    format: SharedCoreTrafficFormat,
    scaleTraffic: (UInt64) throws -> SharedTrafficScale =
      MihomoMeterSharedCoreAdapter.scaleTraffic(bytes:)
  ) -> SharedCoreTrafficRouteResult {
    do {
      let scale = try scaleTraffic(bytes)
      let sharedText = try SharedCoreTrafficDisplayFormatter.string(
        from: scale,
        format: format
      )
      guard sharedText == nativeText else {
        return fallback(nativeText: nativeText, status: .mismatch)
      }
      return SharedCoreTrafficRouteResult(
        text: sharedText,
        source: .sharedPrimary,
        status: .matched
      )
    } catch let error as SharedCoreAdapterError {
      return fallback(nativeText: nativeText, status: status(for: error))
    } catch is SharedCoreTrafficDisplayFormatter.Error {
      return fallback(nativeText: nativeText, status: .unexpectedResult)
    } catch {
      return fallback(nativeText: nativeText, status: .unknownFailure)
    }
  }

  private static func fallback(
    nativeText: String,
    status: SharedCoreTrafficShadowStatus
  ) -> SharedCoreTrafficRouteResult {
    SharedCoreTrafficRouteResult(
      text: nativeText,
      source: .nativeFallback,
      status: status
    )
  }

  private static func status(
    for error: SharedCoreAdapterError
  ) -> SharedCoreTrafficShadowStatus {
    switch error {
    case .nativeCallFailed:
      .nativeCallFailed
    case .unsupportedABIVersion:
      .abiMismatch
    case .unsupportedTrafficUnit:
      .unsupportedTrafficUnit
    }
  }
}
