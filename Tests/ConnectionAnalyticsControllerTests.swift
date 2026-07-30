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

private struct ControllerTestContext {
  let databaseURL: URL
  let calendar: Calendar
  let now: Date
  let cleanup: () -> Void
}
