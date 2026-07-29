import Foundation

struct SubscriptionUserInfoParser {
  func parse(_ headerValue: String) throws -> ActiveQuotaQueryResult {
    let fields = parsedFields(from: headerValue)
    guard
      let upload = fields["upload"],
      let download = fields["download"],
      let total = fields["total"]
    else {
      throw ActiveQuotaQueryError.invalidSubscriptionUserInfo
    }

    do {
      let traffic = try QuotaTraffic(
        uploadBytes: upload,
        downloadBytes: download,
        totalBytes: total
      )
      return ActiveQuotaQueryResult(
        traffic: traffic,
        expireAt: expirationDate(from: fields["expire"])
      )
    } catch {
      throw ActiveQuotaQueryError.invalidSubscriptionUserInfo
    }
  }

  private func parsedFields(from headerValue: String) -> [String: UInt64] {
    headerValue
      .lowercased()
      .replacingOccurrences(of: " ", with: "")
      .split(separator: ";")
      .reduce(into: [String: UInt64]()) { result, field in
        let parts = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard
          parts.count == 2,
          !parts[0].isEmpty,
          let value = byteCount(from: String(parts[1]))
        else {
          return
        }
        result[String(parts[0])] = value
      }
  }

  private func byteCount(from value: String) -> UInt64? {
    guard
      let number = Double(value),
      number.isFinite,
      number >= 0,
      number <= Double(Int64.max)
    else {
      return nil
    }
    return UInt64(number.rounded(.towardZero))
  }

  private func expirationDate(from value: UInt64?) -> Date? {
    guard let value, value > 0 else {
      return nil
    }
    return Date(timeIntervalSince1970: TimeInterval(value))
  }
}
