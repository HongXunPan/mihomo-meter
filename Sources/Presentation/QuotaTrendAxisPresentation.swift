import Foundation

struct QuotaTrendAxisPresentation {
  private let divisor: Double
  private let unit: String
  private let fractionDigits: Int

  init(domain: ClosedRange<Double>) {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var unitIndex = 0
    var divisor = 1.0
    while domain.upperBound / divisor >= 1_000, unitIndex < units.count - 1 {
      divisor *= 1_000
      unitIndex += 1
    }
    self.divisor = divisor
    unit = units[unitIndex]
    // 同一坐标轴固定单位和精度，窄范围保留足以区分相邻刻度的小数。
    let step = max((domain.upperBound - domain.lowerBound) / divisor / 4, 1e-12)
    fractionDigits = unitIndex == 0 ? 0 : max(1, Int(ceil(-log10(step))))
  }

  func bytes(_ value: Double, locale: Locale = .autoupdatingCurrent) -> String {
    guard value.isFinite, value >= 0 else {
      return "—"
    }
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.minimumFractionDigits = fractionDigits
    formatter.maximumFractionDigits = fractionDigits
    guard let number = formatter.string(from: NSNumber(value: value / divisor)) else {
      return "—"
    }
    return "\(number) \(unit)"
  }

  static func compactDate(
    _ date: Date,
    window: QuotaTrendWindow,
    locale: Locale = .autoupdatingCurrent,
    timeZone: TimeZone = .autoupdatingCurrent
  ) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    let template: String
    switch window {
    case .day:
      template = "HHmm"
    case .week, .month:
      template = "Md"
    case .year:
      template = "yyyyM"
    }
    formatter.setLocalizedDateFormatFromTemplate(template)
    return formatter.string(from: date)
  }
}
