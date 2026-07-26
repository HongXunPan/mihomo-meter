import Foundation

struct MihomoProxyProvidersResponse: Decodable, Equatable, Sendable {
  let providers: [String: MihomoProxyProviderResponse]

  var runtimeQuotaSelection: RuntimeQuotaCandidateSelection {
    let candidates = providers.compactMap { sourceKey, provider in
      provider.runtimeQuotaCandidate(sourceKey: sourceKey)
    }
    return RuntimeQuotaCandidateSelection(candidates: candidates)
  }
}

struct MihomoProxyProviderResponse: Decodable, Equatable, Sendable {
  let updatedAt: String?
  let subscriptionInfo: MihomoSubscriptionInfoResponse?

  private enum CodingKeys: String, CodingKey {
    case updatedAt
    case subscriptionInfo
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    updatedAt = try? container.decodeIfPresent(String.self, forKey: .updatedAt)
    subscriptionInfo = try? container.decodeIfPresent(
      MihomoSubscriptionInfoResponse.self,
      forKey: .subscriptionInfo
    )
  }

  func runtimeQuotaCandidate(sourceKey: String) -> RuntimeQuotaCandidate? {
    let normalizedSourceKey = sourceKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      !normalizedSourceKey.isEmpty,
      let subscriptionInfo,
      let upload = subscriptionInfo.upload,
      let download = subscriptionInfo.download,
      let total = subscriptionInfo.total,
      upload >= 0,
      download >= 0,
      total > 0,
      let uploadBytes = UInt64(exactly: upload),
      let downloadBytes = UInt64(exactly: download),
      let totalBytes = UInt64(exactly: total),
      let traffic = try? QuotaTraffic(
        uploadBytes: uploadBytes,
        downloadBytes: downloadBytes,
        totalBytes: totalBytes
      )
    else {
      return nil
    }

    return RuntimeQuotaCandidate(
      sourceKey: normalizedSourceKey,
      sourceUpdatedAt: Self.sourceDate(from: updatedAt),
      traffic: traffic,
      expireAt: subscriptionInfo.expire.flatMap(Self.expireDate)
    )
  }

  private static func sourceDate(from value: String?) -> Date? {
    guard let value else {
      return nil
    }
    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let regularFormatter = ISO8601DateFormatter()
    guard let date = fractionalFormatter.date(from: value) ?? regularFormatter.date(from: value)
    else {
      return nil
    }
    return date.timeIntervalSince1970 > 0 ? date : nil
  }

  private static func expireDate(from value: Int64) -> Date? {
    guard value > 0 else {
      return nil
    }
    return Date(timeIntervalSince1970: TimeInterval(value))
  }
}

struct MihomoSubscriptionInfoResponse: Decodable, Equatable, Sendable {
  let upload: Int64?
  let download: Int64?
  let total: Int64?
  let expire: Int64?

  private enum CodingKeys: String, CodingKey {
    case upload = "Upload"
    case download = "Download"
    case total = "Total"
    case expire = "Expire"
    case lowercaseUpload = "upload"
    case lowercaseDownload = "download"
    case lowercaseTotal = "total"
    case lowercaseExpire = "expire"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    upload = Self.decodeInteger(container, keys: [.upload, .lowercaseUpload])
    download = Self.decodeInteger(container, keys: [.download, .lowercaseDownload])
    total = Self.decodeInteger(container, keys: [.total, .lowercaseTotal])
    expire = Self.decodeInteger(container, keys: [.expire, .lowercaseExpire])
  }

  private static func decodeInteger(
    _ container: KeyedDecodingContainer<CodingKeys>,
    keys: [CodingKeys]
  ) -> Int64? {
    for key in keys {
      if let value = try? container.decodeIfPresent(Int64.self, forKey: key) {
        return value
      }
    }
    return nil
  }
}
