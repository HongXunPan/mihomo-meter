import Foundation

struct TrafficBytes: Equatable, Sendable {
  let upload: UInt64
  let download: UInt64

  static let zero = TrafficBytes(upload: 0, download: 0)

  var total: UInt64 {
    Self.saturatedAdd(upload, download)
  }

  static func + (left: TrafficBytes, right: TrafficBytes) -> TrafficBytes {
    TrafficBytes(
      upload: saturatedAdd(left.upload, right.upload),
      download: saturatedAdd(left.download, right.download)
    )
  }

  static func nonnegativeDelta(current: TrafficBytes, previous: TrafficBytes) -> TrafficBytes? {
    guard current.upload >= previous.upload, current.download >= previous.download else {
      return nil
    }

    return TrafficBytes(
      upload: current.upload - previous.upload,
      download: current.download - previous.download
    )
  }

  static func residual(total: TrafficBytes, subtracting value: TrafficBytes) -> TrafficBytes {
    TrafficBytes(
      upload: total.upload >= value.upload ? total.upload - value.upload : 0,
      download: total.download >= value.download ? total.download - value.download : 0
    )
  }

  private static func saturatedAdd(_ left: UInt64, _ right: UInt64) -> UInt64 {
    let (result, overflowed) = left.addingReportingOverflow(right)
    return overflowed ? UInt64.max : result
  }
}

enum TrafficCategory: String, CaseIterable, Equatable, Sendable {
  case proxy
  case direct
  case reject
  case unknown
}

struct ConnectionTrafficSample: Equatable, Sendable {
  let id: String
  let bytes: TrafficBytes
  let chains: [String]
  let rule: String?
  let metadata: ConnectionMetadata
  let startedAt: Date?

  var metadataAvailability: ConnectionMetadataAvailability {
    metadata.availability
  }

  init(
    id: String,
    bytes: TrafficBytes,
    chains: [String],
    rule: String? = nil,
    metadata: ConnectionMetadata = .unavailable,
    startedAt: Date? = nil
  ) {
    self.id = id
    self.bytes = bytes
    self.chains = chains
    self.rule = rule
    self.metadata = metadata
    self.startedAt = startedAt
  }
}

struct ConnectionTrafficSnapshot: Equatable, Sendable {
  let kernelTotal: TrafficBytes
  let connections: [ConnectionTrafficSample]
}

struct CategorizedTrafficBytes: Equatable, Sendable {
  let proxy: TrafficBytes
  let direct: TrafficBytes
  let reject: TrafficBytes
  let unknown: TrafficBytes

  static let zero = CategorizedTrafficBytes(
    proxy: .zero,
    direct: .zero,
    reject: .zero,
    unknown: .zero
  )

  var classified: TrafficBytes {
    proxy + direct + reject
  }

  func adding(_ bytes: TrafficBytes, to category: TrafficCategory) -> CategorizedTrafficBytes {
    switch category {
    case .proxy:
      CategorizedTrafficBytes(
        proxy: proxy + bytes,
        direct: direct,
        reject: reject,
        unknown: unknown
      )
    case .direct:
      CategorizedTrafficBytes(
        proxy: proxy,
        direct: direct + bytes,
        reject: reject,
        unknown: unknown
      )
    case .reject:
      CategorizedTrafficBytes(
        proxy: proxy,
        direct: direct,
        reject: reject + bytes,
        unknown: unknown
      )
    case .unknown:
      CategorizedTrafficBytes(
        proxy: proxy,
        direct: direct,
        reject: reject,
        unknown: unknown + bytes
      )
    }
  }
}

struct TrafficDeltaReport: Equatable, Sendable {
  let kernel: TrafficBytes
  let categories: CategorizedTrafficBytes

  var coverage: Double {
    let kernelTotal = kernel.total
    guard kernelTotal > 0 else {
      return 1
    }

    return min(Double(categories.classified.total) / Double(kernelTotal), 1)
  }
}

struct ConnectionTrafficDelta: Equatable, Sendable {
  let id: String
  let category: TrafficCategory
  let bytes: TrafficBytes
  let cumulativeBytes: TrafficBytes
  let metadata: ConnectionMetadata
  let startedAt: Date?
}

struct ConnectionDeltaBatch: Equatable, Sendable {
  let traffic: TrafficDeltaReport
  let connections: [ConnectionTrafficDelta]
}

struct LiveProxyConnection: Equatable, Identifiable, Sendable {
  let id: String
  let metadata: ConnectionMetadata
  let rate: TrafficRate
  let cumulativeBytes: TrafficBytes
  let startedAt: Date?

  var totalBytesPerSecond: UInt64 {
    let (total, overflowed) = rate.uploadBytesPerSecond.addingReportingOverflow(
      rate.downloadBytesPerSecond
    )
    return overflowed ? UInt64.max : total
  }
}

struct ConnectionAttributionDelta: Equatable, Sendable {
  let metadata: ConnectionMetadata
  let bytes: TrafficBytes
}

struct CategorizedTrafficRates: Equatable, Sendable {
  let proxy: TrafficRate
  let direct: TrafficRate
  let reject: TrafficRate
  let unknown: TrafficRate

  static let zero = CategorizedTrafficRates(
    proxy: .zero,
    direct: .zero,
    reject: .zero,
    unknown: .zero
  )
}

struct TrafficRateWindow: Equatable, Sendable {
  let raw: CategorizedTrafficRates
  let smoothed: CategorizedTrafficRates
  let coverage: Double
}

enum TrafficCoverageQuality: Equatable, Sendable {
  case unavailable
  case reliable
  case low
}

enum TrafficCoveragePolicy {
  static let minimumReliableCoverage = 0.95

  static func quality(for coverage: Double?) -> TrafficCoverageQuality {
    guard let coverage, coverage.isFinite else {
      return .unavailable
    }
    return coverage >= minimumReliableCoverage ? .reliable : .low
  }
}
