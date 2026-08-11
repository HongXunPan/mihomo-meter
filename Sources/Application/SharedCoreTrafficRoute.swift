import os

struct SharedCoreTrafficRouteObservation: Hashable, Sendable {
  let format: SharedCoreTrafficFormat
  let source: SharedCoreTrafficRouteSource
  let status: SharedCoreTrafficShadowStatus
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
      // 路由诊断不得改变共享主路径或原生回退结果。
    }
    return result.text
  }
}
