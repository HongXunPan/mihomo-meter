import Foundation

enum TrafficRateFormatter {
  struct StatusText: Equatable {
    let download: String
    let upload: String
  }

  private static let units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
  private static let compactUnits = ["B/s", "K/s", "M/s", "G/s", "T/s"]

  static func statusText(for rate: TrafficRate) -> StatusText {
    StatusText(
      download: "↓\(compactString(from: rate.downloadBytesPerSecond))",
      upload: "↑\(compactString(from: rate.uploadBytesPerSecond))"
    )
  }

  static func compactString(from bytesPerSecond: UInt64) -> String {
    let nativeText = nativeCompactString(from: bytesPerSecond)
    return SharedCoreTrafficShadow.observe(
      bytes: bytesPerSecond,
      nativeText: nativeText,
      format: .compactRate
    )
  }

  static func string(from bytesPerSecond: UInt64) -> String {
    let nativeText = nativeString(from: bytesPerSecond)
    return SharedCoreTrafficRoute.resolve(
      bytes: bytesPerSecond,
      nativeText: nativeText,
      format: .rate
    )
  }

  private static func nativeCompactString(from bytesPerSecond: UInt64) -> String {
    guard bytesPerSecond >= 1_000 else {
      return "\(bytesPerSecond)B/s"
    }

    let scaled = scaledValue(from: bytesPerSecond)
    return "\(formattedNumber(from: scaled.value))\(compactUnits[scaled.unitIndex])"
  }

  private static func nativeString(from bytesPerSecond: UInt64) -> String {
    guard bytesPerSecond >= 1_000 else {
      return "\(bytesPerSecond) B/s"
    }

    let scaled = scaledValue(from: bytesPerSecond)
    return "\(formattedNumber(from: scaled.value)) \(units[scaled.unitIndex])"
  }

  static func percentage(from coverage: Double?) -> String {
    guard let coverage, coverage.isFinite else {
      return "—"
    }

    let normalized = min(max(coverage, 0), 1)
    return String(
      format: "%.2f%%",
      locale: Locale(identifier: "en_US_POSIX"),
      normalized * 100
    )
  }

  private static func scaledValue(
    from bytesPerSecond: UInt64
  ) -> (value: Double, unitIndex: Int) {
    var value = Double(bytesPerSecond)
    var unitIndex = 0

    while value >= 1_000, unitIndex < units.count - 1 {
      value /= 1_000
      unitIndex += 1
    }

    return (value, unitIndex)
  }

  private static func formattedNumber(from value: Double) -> String {
    if value >= 100 {
      return String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    if value >= 10 {
      return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    return String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
  }
}
