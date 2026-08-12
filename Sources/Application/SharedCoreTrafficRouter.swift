enum SharedCoreTrafficRouteSource: String, Hashable, Sendable {
  case sharedPrimary = "shared_primary"
  case nativeFallback = "native_fallback"
}

enum SharedCoreTrafficRouteStatus: String, Hashable, Sendable {
  case matched
  case succeeded
  case abiMismatch = "abi_mismatch"
  case nativeCallFailed = "native_call_failed"
  case unexpectedResult = "unexpected_result"
  case mismatch
  case unknownFailure = "unknown_failure"
}

struct SharedCoreTrafficRouteResult: Equatable, Sendable {
  let text: String
  let source: SharedCoreTrafficRouteSource
  let status: SharedCoreTrafficShadowStatus
}

struct SharedCoreTrafficLazyRouteResult: Equatable, Sendable {
  let text: String
  let source: SharedCoreTrafficRouteSource
  let status: SharedCoreTrafficRouteStatus
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

  static func routeLazy(
    bytes: UInt64,
    nativeFallback: () -> String,
    format: SharedCoreTrafficFormat,
    abiVersion: () -> UInt32 = { MihomoMeterSharedCoreAdapter.abiVersion },
    scaleTraffic: (UInt64) throws -> SharedTrafficScale =
      MihomoMeterSharedCoreAdapter.scaleTraffic(bytes:)
  ) -> SharedCoreTrafficLazyRouteResult {
    guard abiVersion() == 1 else {
      return lazyFallback(nativeFallback: nativeFallback, status: .abiMismatch)
    }

    do {
      let scale = try scaleTraffic(bytes)
      let sharedText = try SharedCoreTrafficDisplayFormatter.string(
        from: scale,
        format: format
      )
      return SharedCoreTrafficLazyRouteResult(
        text: sharedText,
        source: .sharedPrimary,
        status: .succeeded
      )
    } catch let error as SharedCoreAdapterError {
      return lazyFallback(
        nativeFallback: nativeFallback,
        status: lazyStatus(for: error)
      )
    } catch is SharedCoreTrafficDisplayFormatter.Error {
      return lazyFallback(nativeFallback: nativeFallback, status: .unexpectedResult)
    } catch {
      return lazyFallback(nativeFallback: nativeFallback, status: .unknownFailure)
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

  private static func lazyFallback(
    nativeFallback: () -> String,
    status: SharedCoreTrafficRouteStatus
  ) -> SharedCoreTrafficLazyRouteResult {
    SharedCoreTrafficLazyRouteResult(
      text: nativeFallback(),
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

  private static func lazyStatus(
    for error: SharedCoreAdapterError
  ) -> SharedCoreTrafficRouteStatus {
    switch error {
    case .nativeCallFailed:
      .nativeCallFailed
    case .unsupportedABIVersion:
      .abiMismatch
    case .unsupportedTrafficUnit:
      .unexpectedResult
    }
  }
}
