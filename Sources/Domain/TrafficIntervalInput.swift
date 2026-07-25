import Foundation

enum TrafficIntervalInput {
  static func normalizedName(_ name: String) throws -> String {
    let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else {
      throw TrafficStatisticsError.invalidIntervalName
    }
    return normalized
  }

  static func normalizedNote(_ note: String?) -> String? {
    let normalized = note?.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.flatMap { $0.isEmpty ? nil : $0 }
  }
}
