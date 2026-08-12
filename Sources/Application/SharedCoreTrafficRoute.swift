import os

struct SharedCoreTrafficRouteObservation: Hashable, Sendable {
  let format: SharedCoreTrafficFormat
  let source: SharedCoreTrafficRouteSource
  let status: SharedCoreTrafficRouteStatus
}

private struct SharedCoreTrafficRouteObservationGate: Sendable {
  private var reportedObservations: Set<SharedCoreTrafficRouteObservation> = []

  mutating func shouldReport(_ observation: SharedCoreTrafficRouteObservation) -> Bool {
    reportedObservations.insert(observation).inserted
  }

  mutating func reset() {
    reportedObservations.removeAll(keepingCapacity: true)
  }
}

enum SharedCoreTrafficRoute {
  typealias Reporter = @Sendable (SharedCoreTrafficRouteObservation) throws -> Void

  private struct State {
    var reporter: Reporter?
    var observationGate = SharedCoreTrafficRouteObservationGate()
  }

  private static let stateLock = OSAllocatedUnfairLock(initialState: State())

  static func configure(reporter: Reporter?) {
    stateLock.withLock { state in
      state.reporter = reporter
      state.observationGate.reset()
    }
  }

  static func resolve(
    bytes: UInt64,
    nativeText: String,
    format: SharedCoreTrafficFormat,
    scaleTraffic: (UInt64) throws -> SharedTrafficScale =
      MihomoMeterSharedCoreAdapter.scaleTraffic(bytes:)
  ) -> String {
    let result = SharedCoreTrafficRouter.route(
      bytes: bytes,
      nativeText: nativeText,
      format: format,
      scaleTraffic: scaleTraffic
    )
    let observation = SharedCoreTrafficRouteObservation(
      format: format,
      source: result.source,
      status: routeStatus(for: result.status)
    )
    report(observation)
    return result.text
  }

  static func resolveLazy(
    bytes: UInt64,
    nativeFallback: () -> String,
    format: SharedCoreTrafficFormat,
    abiVersion: () -> UInt32 = { MihomoMeterSharedCoreAdapter.abiVersion },
    scaleTraffic: (UInt64) throws -> SharedTrafficScale =
      MihomoMeterSharedCoreAdapter.scaleTraffic(bytes:)
  ) -> String {
    let result = SharedCoreTrafficRouter.routeLazy(
      bytes: bytes,
      nativeFallback: nativeFallback,
      format: format,
      abiVersion: abiVersion,
      scaleTraffic: scaleTraffic
    )
    report(
      SharedCoreTrafficRouteObservation(
        format: format,
        source: result.source,
        status: result.status
      )
    )
    return result.text
  }

  private static func report(_ observation: SharedCoreTrafficRouteObservation) {
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
      // 路由诊断不得改变共享主路径或原生回退结果。
    }
  }

  private static func routeStatus(
    for shadowStatus: SharedCoreTrafficShadowStatus
  ) -> SharedCoreTrafficRouteStatus {
    switch shadowStatus {
    case .matched:
      .matched
    case .abiMismatch:
      .abiMismatch
    case .nativeCallFailed:
      .nativeCallFailed
    case .unsupportedTrafficUnit, .unexpectedResult:
      .unexpectedResult
    case .mismatch:
      .mismatch
    case .unknownFailure:
      .unknownFailure
    }
  }
}
