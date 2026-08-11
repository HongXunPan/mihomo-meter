import os

enum SharedCoreTrafficShadow {
  typealias Reporter = @Sendable (SharedCoreTrafficShadowObservation) -> Void

  private struct State {
    var reporter: Reporter?
    var observationGate = SharedCoreTrafficShadowObservationGate()
  }

  private static let stateLock = OSAllocatedUnfairLock(initialState: State())

  static func configure(reporter: Reporter?) {
    stateLock.withLock { state in
      state.reporter = reporter
      state.observationGate.reset()
    }
  }

  static func observe(
    bytes: UInt64,
    nativeText: String,
    format: SharedCoreTrafficFormat
  ) -> String {
    let status = SharedCoreTrafficShadowComparator.compare(
      bytes: bytes,
      nativeText: nativeText,
      format: format
    )
    let observation = SharedCoreTrafficShadowObservation(
      format: format,
      status: status
    )
    let reporter = stateLock.withLock { state -> Reporter? in
      guard let reporter = state.reporter,
        state.observationGate.shouldReport(observation)
      else {
        return nil
      }
      return reporter
    }
    reporter?(observation)
    return nativeText
  }
}
