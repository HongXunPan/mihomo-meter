import Foundation

enum TrafficStatisticsFormatter {
  private static let units = ["B", "KB", "MB", "GB", "TB"]

  static func bytes(_ value: UInt64) -> String {
    guard value >= 1_000 else {
      return "\(value) B"
    }

    var scaledValue = Double(value)
    var unitIndex = 0
    while scaledValue >= 1_000, unitIndex < units.count - 1 {
      scaledValue /= 1_000
      unitIndex += 1
    }

    let number: String
    if scaledValue >= 100 {
      number = String(
        format: "%.0f",
        locale: Locale(identifier: "en_US_POSIX"),
        scaledValue
      )
    } else if scaledValue >= 10 {
      number = String(
        format: "%.1f",
        locale: Locale(identifier: "en_US_POSIX"),
        scaledValue
      )
    } else {
      number = String(
        format: "%.2f",
        locale: Locale(identifier: "en_US_POSIX"),
        scaledValue
      )
    }
    return "\(number) \(units[unitIndex])"
  }

  static func dateTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter.string(from: date)
  }

  static func duration(from start: Date, to end: Date) -> String {
    let totalSeconds = max(Int(end.timeIntervalSince(start)), 0)
    let days = totalSeconds / 86_400
    let hours = (totalSeconds % 86_400) / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60

    if days > 0 {
      return "\(days) 天 \(hours) 小时"
    }
    if hours > 0 {
      return "\(hours) 小时 \(minutes) 分"
    }
    if minutes > 0 {
      return "\(minutes) 分 \(seconds) 秒"
    }
    return "\(seconds) 秒"
  }
}
