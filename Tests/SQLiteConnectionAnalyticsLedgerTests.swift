import Foundation
import XCTest

@testable import MihomoMeter

final class SQLiteConnectionAnalyticsLedgerTests: XCTestCase {
  func testDefaultsToDisabledAndPersistsExplicitEnable() async throws {
    let context = try makeContext()
    defer { context.cleanup() }
    let ledger = SQLiteConnectionAnalyticsLedger(databaseURL: context.databaseURL)

    let initial = try await ledger.prepare(calendar: context.calendar, now: context.now)
    XCTAssertFalse(initial.isHistoryEnabled)
    XCTAssertEqual(initial.recentDays.count, 30)

    _ = try await ledger.record(
      [aggregate(day: context.today, application: "App", hostname: "example.com", total: 10)],
      maximumPairCountPerDay: 5_000,
      calendar: context.calendar,
      now: context.now
    )
    let disabledRecords = try await ledger.records(localDay: context.today)
    XCTAssertTrue(disabledRecords.isEmpty)

    _ = try await ledger.setHistoryEnabled(true, calendar: context.calendar, now: context.now)
    let reopened = SQLiteConnectionAnalyticsLedger(databaseURL: context.databaseURL)
    let snapshot = try await reopened.prepare(calendar: context.calendar, now: context.now)
    XCTAssertTrue(snapshot.isHistoryEnabled)
  }

  func testEnforcesDailyPairLimitAndMergesOverflow() async throws {
    let context = try makeContext()
    defer { context.cleanup() }
    let ledger = SQLiteConnectionAnalyticsLedger(databaseURL: context.databaseURL)
    _ = try await ledger.setHistoryEnabled(true, calendar: context.calendar, now: context.now)

    let snapshot = try await ledger.record(
      [
        aggregate(day: context.today, application: "A", hostname: "a.example", total: 1),
        aggregate(day: context.today, application: "B", hostname: "b.example", total: 2),
        aggregate(day: context.today, application: "C", hostname: "c.example", total: 3),
        aggregate(day: context.today, application: "D", hostname: "d.example", total: 4),
      ],
      maximumPairCountPerDay: 3,
      calendar: context.calendar,
      now: context.now
    )
    let records = try await ledger.records(localDay: context.today)

    XCTAssertEqual(records.count, 3)
    XCTAssertEqual(records.reduce(0) { $0 + $1.bytes.total }, 10)
    XCTAssertEqual(
      records.first {
        $0.applicationName == ConnectionAttributionLabel.overflow
          && $0.hostname == ConnectionAttributionLabel.overflow
      }?.bytes.total,
      7
    )
    XCTAssertEqual(snapshot.recentDays.last?.bytes.total, 10)
  }

  func testClearPreservesEnableSetting() async throws {
    let context = try makeContext()
    defer { context.cleanup() }
    let ledger = SQLiteConnectionAnalyticsLedger(databaseURL: context.databaseURL)
    _ = try await ledger.setHistoryEnabled(true, calendar: context.calendar, now: context.now)
    _ = try await ledger.record(
      [aggregate(day: context.today, application: "App", hostname: "example.com", total: 10)],
      maximumPairCountPerDay: 5_000,
      calendar: context.calendar,
      now: context.now
    )

    let snapshot = try await ledger.clearHistory(calendar: context.calendar, now: context.now)

    XCTAssertTrue(snapshot.isHistoryEnabled)
    let records = try await ledger.records(localDay: context.today)
    XCTAssertTrue(records.isEmpty)
  }

  func testPrunesRecordsOutsideThirtyLocalDays() async throws {
    let context = try makeContext()
    defer { context.cleanup() }
    let ledger = SQLiteConnectionAnalyticsLedger(databaseURL: context.databaseURL)
    let oldDate = try XCTUnwrap(
      context.calendar.date(byAdding: .day, value: -40, to: context.now)
    )
    let oldDay = ConnectionAnalyticsCalendar.localDay(for: oldDate, calendar: context.calendar)
    _ = try await ledger.setHistoryEnabled(true, calendar: context.calendar, now: oldDate)
    _ = try await ledger.record(
      [aggregate(day: oldDay, application: "Old", hostname: "old.example", total: 10)],
      maximumPairCountPerDay: 5_000,
      calendar: context.calendar,
      now: oldDate
    )

    _ = try await ledger.prepare(calendar: context.calendar, now: context.now)

    let oldRecords = try await ledger.records(localDay: oldDay)
    XCTAssertTrue(oldRecords.isEmpty)
  }

  func testReportsUnknownAttributionAsIncompleteCoverage() async throws {
    let context = try makeContext()
    defer { context.cleanup() }
    let ledger = SQLiteConnectionAnalyticsLedger(databaseURL: context.databaseURL)
    _ = try await ledger.setHistoryEnabled(true, calendar: context.calendar, now: context.now)
    let snapshot = try await ledger.record(
      [
        aggregate(day: context.today, application: "App", hostname: "known.example", total: 60),
        aggregate(
          day: context.today,
          application: ConnectionAttributionLabel.unknownApplication,
          hostname: "known.example",
          total: 40
        ),
      ],
      maximumPairCountPerDay: 5_000,
      calendar: context.calendar,
      now: context.now
    )

    XCTAssertEqual(snapshot.recentDays.last?.coverage.hostnameRate, 1)
    XCTAssertEqual(snapshot.recentDays.last?.coverage.applicationRate, 0.6)
    XCTAssertEqual(snapshot.recentDays.last?.coverage.fullyAttributedRate, 0.6)
  }

  func testTrendSupportsSingleAndCrossFiltersAndFillsThirtyDays() async throws {
    let context = try makeContext()
    defer { context.cleanup() }
    let ledger = SQLiteConnectionAnalyticsLedger(databaseURL: context.databaseURL)
    let yesterdayDate = try XCTUnwrap(
      context.calendar.date(byAdding: .day, value: -1, to: context.now)
    )
    let yesterday = ConnectionAnalyticsCalendar.localDay(
      for: yesterdayDate,
      calendar: context.calendar
    )
    _ = try await ledger.setHistoryEnabled(true, calendar: context.calendar, now: context.now)
    _ = try await ledger.record(
      [
        aggregate(day: yesterday, application: "App", hostname: "a.example", total: 10),
        aggregate(day: yesterday, application: "App", hostname: "b.example", total: 20),
        aggregate(day: yesterday, application: "Other", hostname: "a.example", total: 5),
        aggregate(day: context.today, application: "App", hostname: "a.example", total: 40),
        aggregate(
          day: context.today,
          application: ConnectionAttributionLabel.unknownApplication,
          hostname: "a.example",
          total: 7
        ),
      ],
      maximumPairCountPerDay: 5_000,
      calendar: context.calendar,
      now: context.now
    )

    let applicationTrend = try await ledger.trend(
      query: ConnectionAnalyticsTrendQuery(applicationName: "App"),
      calendar: context.calendar,
      now: context.now
    )
    let hostnameTrend = try await ledger.trend(
      query: ConnectionAnalyticsTrendQuery(hostname: "a.example"),
      calendar: context.calendar,
      now: context.now
    )
    let crossTrend = try await ledger.trend(
      query: ConnectionAnalyticsTrendQuery(applicationName: "App", hostname: "a.example"),
      calendar: context.calendar,
      now: context.now
    )
    let unknownTrend = try await ledger.trend(
      query: ConnectionAnalyticsTrendQuery(
        applicationName: ConnectionAttributionLabel.unknownApplication
      ),
      calendar: context.calendar,
      now: context.now
    )

    XCTAssertEqual(applicationTrend.points.count, 30)
    XCTAssertEqual(applicationTrend.points.suffix(2).map(\.bytes.total), [30, 40])
    XCTAssertEqual(hostnameTrend.points.suffix(2).map(\.bytes.total), [15, 47])
    XCTAssertEqual(crossTrend.points.suffix(2).map(\.bytes.total), [10, 40])
    XCTAssertEqual(unknownTrend.points.last?.bytes.total, 7)
    XCTAssertEqual(applicationTrend.points.dropLast(2).reduce(0) { $0 + $1.bytes.total }, 0)
  }

  private func aggregate(
    day: String,
    application: String,
    hostname: String,
    total: UInt64
  ) -> ConnectionAttributionAggregate {
    ConnectionAttributionAggregate(
      key: ConnectionAttributionStorageKey(
        localDay: day,
        applicationName: application,
        hostname: hostname
      ),
      bytes: TrafficBytes(upload: total, download: 0)
    )
  }

  private func makeContext() throws -> TestContext {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("MihomoMeter-ConnectionAnalytics-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
    let now = Date(timeIntervalSince1970: 1_754_000_000)
    return TestContext(
      databaseURL: directory.appendingPathComponent("connection-analytics.sqlite3"),
      calendar: calendar,
      now: now,
      today: ConnectionAnalyticsCalendar.localDay(for: now, calendar: calendar),
      cleanup: {
        try? FileManager.default.removeItem(at: directory)
      }
    )
  }
}

private struct TestContext {
  let databaseURL: URL
  let calendar: Calendar
  let now: Date
  let today: String
  let cleanup: () -> Void
}
