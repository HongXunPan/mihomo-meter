import Foundation

protocol ConnectionAnalyticsLedgerStoring: Sendable {
  func prepare(calendar: Calendar, now: Date) async throws -> ConnectionAnalyticsLedgerSnapshot

  func setHistoryEnabled(
    _ isEnabled: Bool,
    calendar: Calendar,
    now: Date
  ) async throws -> ConnectionAnalyticsLedgerSnapshot

  func record(
    _ aggregates: [ConnectionAttributionAggregate],
    maximumPairCountPerDay: Int,
    calendar: Calendar,
    now: Date
  ) async throws -> ConnectionAnalyticsLedgerSnapshot

  func records(localDay: String) async throws -> [ConnectionAttributionRecord]

  func clearHistory(
    calendar: Calendar,
    now: Date
  ) async throws -> ConnectionAnalyticsLedgerSnapshot
}
