struct SharedCoreProxyTypeRouteResult: Equatable, Sendable {
  let classification: ProxyClassification
  let source: SharedCoreProxyTypeRouteSource
  let status: SharedCoreProxyTypeRouteStatus
}

enum SharedCoreProxyTypeRouter {
  static func route(
    rawType: String,
    nativeClassification: ProxyClassification,
    classifyProxyType: (String) throws -> SharedProxyTypeClassification =
      MihomoMeterSharedCoreAdapter.classifyProxyType
  ) -> SharedCoreProxyTypeRouteResult {
    do {
      let sharedClassification = try classifyProxyType(rawType)
      guard let candidate = platformClassification(from: sharedClassification) else {
        let status: SharedCoreProxyTypeRouteStatus =
          nativeClassification
            == ProxyClassification(category: .unknown, unknownReason: .ambiguousProxyType)
          ? .unrecognized : .mismatch
        return fallback(nativeClassification: nativeClassification, status: status)
      }
      guard candidate == nativeClassification else {
        return fallback(nativeClassification: nativeClassification, status: .mismatch)
      }
      return SharedCoreProxyTypeRouteResult(
        classification: nativeClassification,
        source: .sharedShadow,
        status: .matched
      )
    } catch let error as SharedProxyTypeAdapterError {
      return fallback(
        nativeClassification: nativeClassification,
        status: status(for: error)
      )
    } catch {
      return fallback(nativeClassification: nativeClassification, status: .unknownFailure)
    }
  }

  private static func platformClassification(
    from sharedClassification: SharedProxyTypeClassification
  ) -> ProxyClassification? {
    switch sharedClassification {
    case .unrecognized:
      nil
    case .proxy:
      ProxyClassification(category: .proxy, unknownReason: nil)
    case .direct:
      ProxyClassification(category: .direct, unknownReason: nil)
    case .reject:
      ProxyClassification(category: .reject, unknownReason: nil)
    }
  }

  private static func fallback(
    nativeClassification: ProxyClassification,
    status: SharedCoreProxyTypeRouteStatus
  ) -> SharedCoreProxyTypeRouteResult {
    SharedCoreProxyTypeRouteResult(
      classification: nativeClassification,
      source: .nativeFallback,
      status: status
    )
  }

  private static func status(
    for error: SharedProxyTypeAdapterError
  ) -> SharedCoreProxyTypeRouteStatus {
    switch error {
    case .nativeCallFailed:
      .nativeCallFailed
    case .proxyTypeInputTooLong:
      .inputTooLong
    case .unsupportedABIVersion:
      .abiMismatch
    case .unsupportedProxyTypeCategory:
      .unexpectedResult
    case .unsupportedProxyTypeInput:
      .unsupportedInput
    }
  }
}
