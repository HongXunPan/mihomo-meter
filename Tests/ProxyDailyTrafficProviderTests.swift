import Foundation
import XCTest

@testable import MihomoMeter

final class ProxyDailyTrafficProviderTests: SQLiteTrafficLedgerTestCase {
  func testReadsSelectedLocalDayFromCoreProxyLedger() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let calendar = calendar(timeZoneSecondsFromGMT: 0)
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let ledger = SQLiteTrafficLedger(databaseURL: database)

    _ = try await ledger.prepare(calendar: calendar, now: start)
    _ = try await ledger.beginMonitoring(version: "test", at: start, calendar: calendar)
    _ = try await ledger.record(
      baseline(at: start, upload: 100, download: 200),
      calendar: calendar
    )
    let snapshot = try await ledger.record(
      delta(
        at: start.addingTimeInterval(1),
        kernelUpload: 103,
        kernelDownload: 205,
        proxy: TrafficBytes(upload: 3, download: 5)
      ),
      calendar: calendar
    )
    let localDay = try XCTUnwrap(snapshot.recentProxyDays.last?.localDay)

    let result = try await ledger.proxyTraffic(
      localDay: localDay,
      calendar: calendar,
      now: start.addingTimeInterval(1)
    )

    XCTAssertEqual(result, TrafficBytes(upload: 3, download: 5))
  }
}
