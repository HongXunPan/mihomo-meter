import Foundation

@MainActor
protocol TrafficStatisticsRecording: AnyObject {
  func beginMonitoring(version: String, at date: Date) async
  func record(_ observation: TrafficLedgerObservation) async
  func interruptMonitoring(at date: Date) async
}

@MainActor
final class NoOpTrafficStatisticsRecorder: TrafficStatisticsRecording {
  static let shared = NoOpTrafficStatisticsRecorder()

  private init() {}

  func beginMonitoring(version: String, at date: Date) async {}

  func record(_ observation: TrafficLedgerObservation) async {}

  func interruptMonitoring(at date: Date) async {}
}
