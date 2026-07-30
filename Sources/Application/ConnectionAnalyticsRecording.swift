import Foundation

@MainActor
protocol ConnectionAnalyticsRecording: AnyObject {
  func record(_ deltas: [ConnectionAttributionDelta], at date: Date) async
  func flushPending() async
}

@MainActor
protocol ConnectionAnalyticsHistoryClearing: AnyObject {
  @discardableResult
  func clearHistory() async -> Bool
}

@MainActor
final class NoOpConnectionAnalyticsRecorder: ConnectionAnalyticsRecording {
  static let shared = NoOpConnectionAnalyticsRecorder()

  private init() {}

  func record(_ deltas: [ConnectionAttributionDelta], at date: Date) async {}

  func flushPending() async {}
}
