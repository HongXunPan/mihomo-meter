import Foundation

enum SharedCoreTrafficDisplayFormatter {
  enum Error: Swift.Error, Equatable {
    case unsupportedDecimalPlaces(UInt32)
  }

  static func string(
    from scale: SharedTrafficScale,
    format: SharedCoreTrafficFormat
  ) throws -> String {
    let number = try formattedNumber(from: scale)
    let unit = unitText(for: scale.unit, format: format)

    switch format {
    case .byteCount:
      return "\(number) \(unit)"
    case .rate:
      return "\(number) \(unit)/s"
    case .compactRate:
      return "\(number)\(unit)/s"
    }
  }

  private static func formattedNumber(from scale: SharedTrafficScale) throws -> String {
    let format: String
    switch scale.decimalPlaces {
    case 0:
      format = "%.0f"
    case 1:
      format = "%.1f"
    case 2:
      format = "%.2f"
    default:
      throw Error.unsupportedDecimalPlaces(scale.decimalPlaces)
    }
    return String(
      format: format,
      locale: Locale(identifier: "en_US_POSIX"),
      scale.value
    )
  }

  private static func unitText(
    for unit: SharedTrafficUnit,
    format: SharedCoreTrafficFormat
  ) -> String {
    switch (unit, format) {
    case (.bytes, _):
      return "B"
    case (.kilobytes, .compactRate):
      return "K"
    case (.megabytes, .compactRate):
      return "M"
    case (.gigabytes, .compactRate):
      return "G"
    case (.terabytes, .compactRate):
      return "T"
    case (.kilobytes, _):
      return "KB"
    case (.megabytes, _):
      return "MB"
    case (.gigabytes, _):
      return "GB"
    case (.terabytes, _):
      return "TB"
    }
  }
}
