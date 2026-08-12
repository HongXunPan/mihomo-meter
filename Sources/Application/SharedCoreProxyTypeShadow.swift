import os

enum SharedCoreProxyTypeShadow {
  typealias Reporter = @Sendable (SharedCoreProxyTypeShadowObservation) throws -> Void

  private struct State {
    var reporter: Reporter?
    var observationGate = SharedCoreProxyTypeShadowObservationGate()
  }

  private static let stateLock = OSAllocatedUnfairLock(initialState: State())

  static func configure(reporter: Reporter?) {
    stateLock.withLock { state in
      state.reporter = reporter
      state.observationGate.reset()
    }
  }

  static func observe(
    rawType: String,
    nativeClassification: ProxyClassification
  ) -> ProxyClassification {
    observe(
      rawType: rawType,
      nativeClassification: nativeClassification,
      classifyProxyType: MihomoMeterSharedCoreAdapter.classifyProxyType
    )
  }

  static func observe(
    rawType: String,
    nativeClassification: ProxyClassification,
    classifyProxyType: (String) throws -> SharedProxyTypeClassification
  ) -> ProxyClassification {
    let result = SharedCoreProxyTypeRouter.route(
      rawType: rawType,
      nativeClassification: nativeClassification,
      classifyProxyType: classifyProxyType
    )
    let observation = SharedCoreProxyTypeShadowObservation(
      source: result.source,
      status: result.status
    )
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
      // 代理分类影子诊断不得改变仍由原生分类决定的生产结果。
    }
    return nativeClassification
  }
}
