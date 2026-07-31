import Foundation

protocol TrafficLedgerStoring: Sendable {
  func prepare(calendar: Calendar, now: Date) async throws -> TrafficStatisticsSnapshot

  func beginMonitoring(
    version: String,
    at date: Date,
    calendar: Calendar
  ) async throws -> TrafficStatisticsSnapshot

  func record(
    _ observation: TrafficLedgerObservation,
    calendar: Calendar
  ) async throws -> TrafficStatisticsSnapshot

  func startInterval(
    name: String,
    note: String?,
    at date: Date,
    calendar: Calendar
  ) async throws -> TrafficStatisticsSnapshot

  func stopInterval(
    id: UUID,
    at date: Date,
    calendar: Calendar
  ) async throws -> TrafficStatisticsSnapshot

  func renameInterval(
    id: UUID,
    name: String,
    calendar: Calendar,
    now: Date
  ) async throws -> TrafficStatisticsSnapshot

  func deleteInterval(
    id: UUID,
    calendar: Calendar,
    now: Date
  ) async throws -> TrafficStatisticsSnapshot

  func interruptActiveIntervals(
    reason: TrafficIntervalEndReason,
    calendar: Calendar,
    now: Date
  ) async throws -> TrafficStatisticsSnapshot

  func clear(calendar: Calendar, now: Date) async throws -> TrafficStatisticsSnapshot
}

protocol ProxyDailyTrafficProviding: Sendable {
  func proxyTraffic(
    localDay: String,
    calendar: Calendar,
    now: Date
  ) async throws -> TrafficBytes
}
