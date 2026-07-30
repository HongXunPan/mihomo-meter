import Foundation

struct ConnectionAnalyticsTrendQuery: Equatable, Sendable {
  let applicationName: String?
  let hostname: String?

  init(applicationName: String? = nil, hostname: String? = nil) {
    precondition(applicationName != nil || hostname != nil)
    self.applicationName = applicationName
    self.hostname = hostname
  }
}

struct ConnectionAnalyticsTrendPoint: Equatable, Identifiable, Sendable {
  let localDay: String
  let bytes: TrafficBytes

  var id: String {
    localDay
  }
}

struct ConnectionAnalyticsTrend: Equatable, Sendable {
  let points: [ConnectionAnalyticsTrendPoint]

  var totalBytes: TrafficBytes {
    points.reduce(.zero) { $0 + $1.bytes }
  }

  var activeDayCount: Int {
    points.count { $0.bytes.total > 0 }
  }

  var activeDailyAverageBytes: UInt64 {
    guard activeDayCount > 0 else {
      return 0
    }
    return totalBytes.total / UInt64(activeDayCount)
  }

  var peakPoint: ConnectionAnalyticsTrendPoint? {
    points.reduce(nil) { peak, point in
      guard point.bytes.total > 0 else {
        return peak
      }
      guard let peak else {
        return point
      }
      return point.bytes.total >= peak.bytes.total ? point : peak
    }
  }

  var defaultSelectedLocalDay: String? {
    points.last { $0.bytes.total > 0 }?.localDay
  }
}
