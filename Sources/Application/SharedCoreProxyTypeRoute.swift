import os

enum SharedCoreProxyTypeRoute {
  typealias Reporter = @Sendable (SharedCoreProxyTypeRouteObservation) throws -> Void

  private struct State {
    var reporter: Reporter?
    var observationGate = SharedCoreProxyTypeRouteObservationGate()
  }

  private static let stateLock = OSAllocatedUnfairLock(initialState: State())

  static func configure(reporter: Reporter?) {
    stateLock.withLock { state in
      state.reporter = reporter
      state.observationGate.reset()
    }
  }

  static func resolve(
    rawType: String,
    nativeClassification: ProxyClassification
  ) -> ProxyClassification {
    resolve(
      rawType: rawType,
      nativeClassification: nativeClassification,
      classifyProxyType: MihomoMeterSharedCoreAdapter.classifyProxyType
    )
  }

  static func resolveLazy(
    rawType: String,
    nativeFallback: @Sendable () -> ProxyClassification
  ) -> ProxyClassification {
    resolveLazy(
      rawType: rawType,
      nativeFallback: nativeFallback,
      classifyProxyType: MihomoMeterSharedCoreAdapter.classifyProxyType
    )
  }

  static func resolveLazy(
    rawType: String,
    nativeFallback: @Sendable () -> ProxyClassification,
    classifyProxyType: (String) throws -> SharedProxyTypeClassification
  ) -> ProxyClassification {
    let result = SharedCoreProxyTypeRouter.routeLazy(
      rawType: rawType,
      nativeFallback: nativeFallback,
      classifyProxyType: classifyProxyType
    )
    report(
      SharedCoreProxyTypeRouteObservation(
        source: result.source,
        status: result.status
      )
    )
    return result.classification
  }

  static func resolve(
    rawType: String,
    nativeClassification: ProxyClassification,
    classifyProxyType: (String) throws -> SharedProxyTypeClassification
  ) -> ProxyClassification {
    let result = SharedCoreProxyTypeRouter.route(
      rawType: rawType,
      nativeClassification: nativeClassification,
      classifyProxyType: classifyProxyType
    )
    report(
      SharedCoreProxyTypeRouteObservation(
        source: result.source,
        status: result.status
      )
    )
    return result.classification
  }

  private static func report(_ observation: SharedCoreProxyTypeRouteObservation) {
    let reporter = stateLock.withLock { state -> Reporter? in
      guard let reporter = state.reporter,
        state.observationGate.shouldReport(observation)
      else {
        return nil
      }
      return reporter
    }
    do {
      try reporter?(observation)
    } catch {
      // 路由诊断不得改变共享分类或原生回退结果。
    }
  }
}
