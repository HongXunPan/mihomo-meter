import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class ConnectionAnalyticsControllerTests: XCTestCase {
  func testDoesNotRecordUntilExplicitlyEnabled() async throws {
    let context = try makeContext()
    defer { context.cleanup() }
    let ledger = SQLiteConnectionAnalyticsLedger(databaseURL: context.databaseURL)
    let controller = makeController(context: context, ledger: ledger)
    await controller.prepare()

    await controller.record([delta(total: 10)], at: context.now)
    await controller.flushPending()
    XCTAssertTrue(controller.selectedRecords.isEmpty)

    await controller.setHistoryEnabled(true)
    await controller.record([delta(total: 20)], at: context.now)
    await controller.flushPending()

    XCTAssertEqual(controller.selectedRecords.count, 1)
    XCTAssertEqual(controller.selectedRecords.first?.applicationName, "Example")
    XCTAssertEqual(controller.selectedRecords.first?.hostname, "example.com")
    XCTAssertEqual(controller.selectedRecords.first?.bytes.total, 20)
  }

  func testDisableFlushesPendingDataAndStopsNewWrites() async throws {
    let context = try makeContext()
    defer { context.cleanup() }
    let ledger = SQLiteConnectionAnalyticsLedger(databaseURL: context.databaseURL)
    let controller = makeController(context: context, ledger: ledger)
    await controller.prepare()
    await controller.setHistoryEnabled(true)
    await controller.record([delta(total: 30)], at: context.now)

    await controller.setHistoryEnabled(false)
    await controller.record([delta(total: 50)], at: context.now)
    await controller.flushPending()

    XCTAssertFalse(controller.isHistoryEnabled)
    XCTAssertEqual(controller.selectedRecords.first?.bytes.total, 30)
  }

  func testScheduledFlushPersistsCoalescedDeltas() async throws {
    let context = try makeContext()
    defer { context.cleanup() }
    let ledger = SQLiteConnectionAnalyticsLedger(databaseURL: context.databaseURL)
    let controller = ConnectionAnalyticsController(
      ledger: ledger,
      calendar: context.calendar,
      flushIntervalNanoseconds: 1_000_000,
      now: { context.now }
    )
    await controller.prepare()
    await controller.setHistoryEnabled(true)

    await controller.record([delta(total: 10), delta(total: 20)], at: context.now)
    try await Task.sleep(nanoseconds: 20_000_000)

    XCTAssertEqual(controller.selectedRecords.first?.bytes.total, 30)
  }

  func testTrendFlushesPendingDataBeforeQuery() async throws {
    let context = try makeContext()
    defer { context.cleanup() }
    let ledger = SQLiteConnectionAnalyticsLedger(databaseURL: context.databaseURL)
    let controller = makeController(context: context, ledger: ledger)
    await controller.prepare()
    await controller.setHistoryEnabled(true)
    await controller.record([delta(total: 42)], at: context.now)

    let trend = try await controller.trend(
      query: ConnectionAnalyticsTrendQuery(applicationName: "Example")
    )

    XCTAssertEqual(trend.points.last?.bytes.total, 42)
    XCTAssertEqual(controller.availability, .available)
  }

  func testTrendQueryFailureDoesNotDisableConnectionAnalytics() async throws {
    let ledger = FailingConnectionAnalyticsLedger(failure: .trend)
    let controller = ConnectionAnalyticsController(ledger: ledger)
    await controller.prepare()

    do {
      _ = try await controller.trend(
        query: ConnectionAnalyticsTrendQuery(hostname: "example.com")
      )
      XCTFail("趋势查询应失败")
    } catch {
      XCTAssertEqual(controller.availability, .available)
      XCTAssertNil(controller.operationMessage)
    }
  }

  func testTrendPendingFlushFailureDoesNotDisableConnectionAnalytics() async throws {
    let ledger = FailingConnectionAnalyticsLedger(failure: .record)
    let controller = ConnectionAnalyticsController(ledger: ledger)
    await controller.prepare()
    await controller.record([delta(total: 12)], at: Date())

    do {
      _ = try await controller.trend(
        query: ConnectionAnalyticsTrendQuery(applicationName: "Example")
      )
      XCTFail("待写数据刷新应失败")
    } catch {
      XCTAssertEqual(controller.availability, .available)
      XCTAssertNil(controller.operationMessage)
    }
  }

  private func makeController(
    context: ControllerTestContext,
    ledger: SQLiteConnectionAnalyticsLedger
  ) -> ConnectionAnalyticsController {
    ConnectionAnalyticsController(
      ledger: ledger,
      calendar: context.calendar,
      now: { context.now }
    )
  }

  private func delta(total: UInt64) -> ConnectionAttributionDelta {
    ConnectionAttributionDelta(
      metadata: ConnectionMetadata(hostname: "example.com", applicationName: "Example"),
      bytes: TrafficBytes(upload: total, download: 0)
    )
  }

  private func makeContext() throws -> ControllerTestContext {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("MihomoMeter-ConnectionController-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
    return ControllerTestContext(
      databaseURL: directory.appendingPathComponent("connection-analytics.sqlite3"),
      calendar: calendar,
      now: Date(timeIntervalSince1970: 1_754_000_000),
      cleanup: {
        try? FileManager.default.removeItem(at: directory)
      }
    )
  }
}

private actor FailingConnectionAnalyticsLedger: ConnectionAnalyticsLedgerStoring {
  enum Failure: Equatable {
    case record
    case trend
  }

  private let failure: Failure

  init(failure: Failure) {
    self.failure = failure
  }

  func prepare(calendar: Calendar, now: Date) async throws -> ConnectionAnalyticsLedgerSnapshot {
    snapshot(calendar: calendar, now: now)
  }

  func setHistoryEnabled(
    _ isEnabled: Bool,
    calendar: Calendar,
    now: Date
  ) async throws -> ConnectionAnalyticsLedgerSnapshot {
    snapshot(calendar: calendar, now: now)
  }

  func record(
    _ aggregates: [ConnectionAttributionAggregate],
    maximumPairCountPerDay: Int,
    calendar: Calendar,
    now: Date
  ) async throws -> ConnectionAnalyticsLedgerSnapshot {
    if failure == .record {
      throw ConnectionAnalyticsError.database("待写数据刷新失败")
    }
    return snapshot(calendar: calendar, now: now)
  }

  func records(localDay: String) async throws -> [ConnectionAttributionRecord] {
    []
  }

  func trend(
    query: ConnectionAnalyticsTrendQuery,
    calendar: Calendar,
    now: Date
  ) async throws -> ConnectionAnalyticsTrend {
    if failure == .trend {
      throw ConnectionAnalyticsError.database("趋势查询失败")
    }
    return ConnectionAnalyticsTrend(points: [])
  }

  func clearHistory(
    calendar: Calendar,
    now: Date
  ) async throws -> ConnectionAnalyticsLedgerSnapshot {
    snapshot(calendar: calendar, now: now)
  }

  private func snapshot(
    calendar: Calendar,
    now: Date
  ) -> ConnectionAnalyticsLedgerSnapshot {
    ConnectionAnalyticsLedgerSnapshot(
      isHistoryEnabled: true,
      recentDays: [
        ConnectionAnalyticsDay(
          localDay: ConnectionAnalyticsCalendar.localDay(for: now, calendar: calendar),
          bytes: .zero,
          coverage: .empty
        )
      ]
    )
  }
}

private struct ControllerTestContext {
  let databaseURL: URL
  let calendar: Calendar
  let now: Date
  let cleanup: () -> Void
}
