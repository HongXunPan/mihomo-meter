struct TrafficRateAggregator: Sendable {
  private let windowDuration: Double
  private let smoothingWindowCount: Int
  private var accumulatedDuration = 0.0
  private var accumulatedKernel = TrafficBytes.zero
  private var accumulatedCategories = CategorizedTrafficBytes.zero
  private var recentRawRates: [CategorizedTrafficRates] = []

  init(windowDuration: Double = 1, smoothingWindowCount: Int = 2) {
    precondition(windowDuration > 0)
    precondition(smoothingWindowCount > 0)
    self.windowDuration = windowDuration
    self.smoothingWindowCount = smoothingWindowCount
  }

  mutating func consume(
    _ report: TrafficDeltaReport,
    elapsedSeconds: Double
  ) -> TrafficRateWindow? {
    guard elapsedSeconds.isFinite, elapsedSeconds > 0 else {
      return nil
    }

    accumulatedDuration += elapsedSeconds
    accumulatedKernel = accumulatedKernel + report.kernel
    accumulatedCategories = add(accumulatedCategories, report.categories)

    guard accumulatedDuration >= windowDuration else {
      return nil
    }

    let aggregate = TrafficDeltaReport(
      kernel: accumulatedKernel,
      categories: accumulatedCategories
    )
    let raw = rates(from: accumulatedCategories, duration: accumulatedDuration)
    recentRawRates.append(raw)
    if recentRawRates.count > smoothingWindowCount {
      recentRawRates.removeFirst(recentRawRates.count - smoothingWindowCount)
    }

    let window = TrafficRateWindow(
      raw: raw,
      smoothed: average(recentRawRates),
      coverage: aggregate.coverage
    )
    accumulatedDuration = 0
    accumulatedKernel = .zero
    accumulatedCategories = .zero
    return window
  }

  mutating func reset() {
    accumulatedDuration = 0
    accumulatedKernel = .zero
    accumulatedCategories = .zero
    recentRawRates = []
  }

  private func rates(
    from categories: CategorizedTrafficBytes,
    duration: Double
  ) -> CategorizedTrafficRates {
    CategorizedTrafficRates(
      proxy: rate(from: categories.proxy, duration: duration),
      direct: rate(from: categories.direct, duration: duration),
      reject: rate(from: categories.reject, duration: duration),
      unknown: rate(from: categories.unknown, duration: duration)
    )
  }

  private func rate(from bytes: TrafficBytes, duration: Double) -> TrafficRate {
    TrafficRate(
      uploadBytesPerSecond: bytesPerSecond(bytes.upload, duration: duration),
      downloadBytesPerSecond: bytesPerSecond(bytes.download, duration: duration)
    )
  }

  private func bytesPerSecond(_ bytes: UInt64, duration: Double) -> UInt64 {
    let value = Double(bytes) / duration
    guard value < Double(UInt64.max) else {
      return UInt64.max
    }
    return UInt64(value)
  }

  private func average(_ rates: [CategorizedTrafficRates]) -> CategorizedTrafficRates {
    CategorizedTrafficRates(
      proxy: average(rates.map(\.proxy)),
      direct: average(rates.map(\.direct)),
      reject: average(rates.map(\.reject)),
      unknown: average(rates.map(\.unknown))
    )
  }

  private func average(_ rates: [TrafficRate]) -> TrafficRate {
    let count = UInt64(rates.count)
    guard count > 0 else {
      return .zero
    }

    let totals = rates.reduce(TrafficBytes.zero) {
      $0
        + TrafficBytes(
          upload: $1.uploadBytesPerSecond,
          download: $1.downloadBytesPerSecond
        )
    }
    return TrafficRate(
      uploadBytesPerSecond: totals.upload / count,
      downloadBytesPerSecond: totals.download / count
    )
  }

  private func add(
    _ left: CategorizedTrafficBytes,
    _ right: CategorizedTrafficBytes
  ) -> CategorizedTrafficBytes {
    CategorizedTrafficBytes(
      proxy: left.proxy + right.proxy,
      direct: left.direct + right.direct,
      reject: left.reject + right.reject,
      unknown: left.unknown + right.unknown
    )
  }
}
