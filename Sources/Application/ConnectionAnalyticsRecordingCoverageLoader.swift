import Foundation

struct ConnectionAnalyticsRecordingCoverageLoader: Sendable {
  let source: (any ProxyDailyTrafficProviding)?

  func load(
    localDay: String,
    attributed: TrafficBytes,
    calendar: Calendar,
    now: Date
  ) async -> ConnectionAnalyticsRecordingCoverage? {
    guard let source else {
      return nil
    }
    do {
      let coreProxy = try await source.proxyTraffic(
        localDay: localDay,
        calendar: calendar,
        now: now
      )
      return ConnectionAnalyticsRecordingCoverage(
        attributed: attributed,
        coreProxy: coreProxy
      )
    } catch {
      return nil
    }
  }
}
