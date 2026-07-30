import Foundation
import XCTest

@testable import MihomoMeter

final class TrafficDailyTotalsTests: SQLiteTrafficLedgerTestCase {
  func testFillsThirtyLocalDaysAndIncludesToday() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let calendar = calendar(timeZoneSecondsFromGMT: 8 * 3_600)
    let firstDay = Date(timeIntervalSince1970: 1_754_000_000)
    let secondDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: firstDay))
    let ledger = SQLiteTrafficLedger(databaseURL: database)

    _ = try await ledger.prepare(calendar: calendar, now: firstDay)
    _ = try await ledger.beginMonitoring(version: "test", at: firstDay, calendar: calendar)
    _ = try await ledger.record(
      baseline(at: firstDay, upload: 100, download: 200),
      calendar: calendar
    )
    _ = try await ledger.record(
      delta(
        at: firstDay.addingTimeInterval(1),
        kernelUpload: 110,
        kernelDownload: 220,
        proxy: TrafficBytes(upload: 10, download: 20)
      ),
      calendar: calendar
    )
    let snapshot = try await ledger.record(
      delta(
        at: secondDay,
        kernelUpload: 115,
        kernelDownload: 228,
        proxy: TrafficBytes(upload: 5, download: 8)
      ),
      calendar: calendar
    )

    XCTAssertEqual(snapshot.recentProxyDays.count, 30)
    XCTAssertEqual(snapshot.recentProxyDays.suffix(2).first?.bytes.total, 30)
    XCTAssertEqual(snapshot.recentProxyDays.last?.bytes.total, 13)
    XCTAssertEqual(
      snapshot.recentProxyDays.last?.localDay,
      TrafficLedgerPersistence.localDay(for: secondDay, calendar: calendar)
    )
  }
}
