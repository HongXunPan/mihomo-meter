import os

enum SharedCoreTrafficShadow {
  typealias Reporter = @Sendable (SharedCoreTrafficShadowObservation) -> Void

  private static let reporterLock = OSAllocatedUnfairLock<Reporter?>(initialState: nil)

  static func configure(reporter: Reporter?) {
    reporterLock.withLock { currentReporter in
      currentReporter = reporter
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
    guard status != .matched else {
      return nativeText
    }

    let observation = SharedCoreTrafficShadowObservation(
      format: format,
      status: status
    )
    let reporter = reporterLock.withLock { $0 }
    reporter?(observation)
    return nativeText
  }
}
