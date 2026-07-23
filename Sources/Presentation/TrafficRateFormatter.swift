import Foundation

enum TrafficRateFormatter {
  private static let units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]

  static func statusTitle(for rate: TrafficRate) -> String {
    "P ↓ \(string(from: rate.downloadBytesPerSecond))  ↑ \(string(from: rate.uploadBytesPerSecond))"
  }

  static func string(from bytesPerSecond: UInt64) -> String {
    guard bytesPerSecond >= 1_000 else {
      return "\(bytesPerSecond) B/s"
    }

    var value = Double(bytesPerSecond)
    var unitIndex = 0

    while value >= 1_000, unitIndex < units.count - 1 {
      value /= 1_000
      unitIndex += 1
    }

    let number: String
    if value >= 100 {
      number = String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), value)
    } else if value >= 10 {
      number = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    } else {
      number = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    return "\(number) \(units[unitIndex])"
  }
}
