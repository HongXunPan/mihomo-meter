import Foundation
import XCTest

@testable import MihomoMeter

final class SQLiteTrafficLedgerTests: SQLiteTrafficLedgerTestCase {
  func testOverlappingIntervalsKeepIndependentProxyBaselines() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let calendar = calendar(timeZoneSecondsFromGMT: 0)
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let ledger = SQLiteTrafficLedger(databaseURL: database)

    _ = try await ledger.prepare(calendar: calendar, now: start)
    _ = try await ledger.beginMonitoring(version: "test", at: start, calendar: calendar)
    _ = try await ledger.record(
      baseline(at: start, upload: 1_000, download: 2_000),
      calendar: calendar
    )
    var snapshot = try await ledger.startInterval(
      name: "下载镜像",
      note: nil,
      at: start.addingTimeInterval(1),
      calendar: calendar
    )
    let firstID = try XCTUnwrap(snapshot.intervals.first?.id)

    _ = try await ledger.record(
      delta(
        at: start.addingTimeInterval(2),
        kernelUpload: 1_100,
        kernelDownload: 2_200,
        proxy: TrafficBytes(upload: 100, download: 200)
      ),
      calendar: calendar
    )
    snapshot = try await ledger.startInterval(
      name: "视频会议",
      note: "重叠任务",
      at: start.addingTimeInterval(3),
      calendar: calendar
    )
    let secondID = try XCTUnwrap(snapshot.intervals.first { $0.name == "视频会议" }?.id)

    _ = try await ledger.record(
      delta(
        at: start.addingTimeInterval(4),
        kernelUpload: 1_130,
        kernelDownload: 2_240,
        proxy: TrafficBytes(upload: 30, download: 40)
      ),
      calendar: calendar
    )
    snapshot = try await ledger.stopInterval(
      id: firstID,
      at: start.addingTimeInterval(5),
      calendar: calendar
    )
    XCTAssertEqual(
      snapshot.intervals.first { $0.id == firstID }?.proxyUsage,
      TrafficBytes(upload: 130, download: 240)
    )

    _ = try await ledger.record(
      delta(
        at: start.addingTimeInterval(6),
        kernelUpload: 1_135,
        kernelDownload: 2_246,
        proxy: TrafficBytes(upload: 5, download: 6)
      ),
      calendar: calendar
    )
    snapshot = try await ledger.stopInterval(
      id: secondID,
      at: start.addingTimeInterval(7),
      calendar: calendar
    )
    XCTAssertEqual(
      snapshot.intervals.first { $0.id == secondID }?.proxyUsage,
      TrafficBytes(upload: 35, download: 46)
    )

    snapshot = try await ledger.deleteInterval(
      id: firstID,
      calendar: calendar,
      now: start.addingTimeInterval(8)
    )
    XCTAssertNil(snapshot.intervals.first { $0.id == firstID })
    XCTAssertEqual(snapshot.lifetime.proxy, TrafficBytes(upload: 135, download: 246))
  }

  func testRestartInterruptsActiveIntervalAtLastObservation() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let calendar = calendar(timeZoneSecondsFromGMT: 0)
    let start = Date(timeIntervalSince1970: 1_700_100_000)
    let lastObservation = start.addingTimeInterval(20)

    do {
      let ledger = SQLiteTrafficLedger(databaseURL: database)
      _ = try await ledger.prepare(calendar: calendar, now: start)
      _ = try await ledger.beginMonitoring(version: "test", at: start, calendar: calendar)
      _ = try await ledger.record(
        baseline(at: start, upload: 50, download: 80),
        calendar: calendar
      )
      _ = try await ledger.startInterval(
        name: "会话",
        note: nil,
        at: start.addingTimeInterval(5),
        calendar: calendar
      )
      _ = try await ledger.record(
        delta(
          at: lastObservation,
          kernelUpload: 62,
          kernelDownload: 114,
          proxy: TrafficBytes(upload: 12, download: 34)
        ),
        calendar: calendar
      )
    }

    let reopened = SQLiteTrafficLedger(databaseURL: database)
    let snapshot = try await reopened.prepare(
      calendar: calendar,
      now: start.addingTimeInterval(200)
    )
    let interval = try XCTUnwrap(snapshot.intervals.first)
    XCTAssertEqual(interval.status, .interrupted)
    XCTAssertEqual(interval.endReason, .recovery)
    XCTAssertEqual(interval.endedAt, lastObservation)
    XCTAssertEqual(interval.proxyUsage, TrafficBytes(upload: 12, download: 34))
  }

  func testNormalTerminationInterruptsAtLastObservation() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let calendar = calendar(timeZoneSecondsFromGMT: 0)
    let start = Date(timeIntervalSince1970: 1_700_150_000)
    let lastObservation = start.addingTimeInterval(10)
    let ledger = SQLiteTrafficLedger(databaseURL: database)

    _ = try await ledger.prepare(calendar: calendar, now: start)
    _ = try await ledger.beginMonitoring(version: "test", at: start, calendar: calendar)
    _ = try await ledger.record(
      baseline(at: start, upload: 100, download: 200),
      calendar: calendar
    )
    _ = try await ledger.startInterval(
      name: "退出测试",
      note: nil,
      at: start.addingTimeInterval(1),
      calendar: calendar
    )
    _ = try await ledger.record(
      delta(
        at: lastObservation,
        kernelUpload: 107,
        kernelDownload: 211,
        proxy: TrafficBytes(upload: 7, download: 11)
      ),
      calendar: calendar
    )
    let snapshot = try await ledger.interruptActiveIntervals(
      reason: .applicationExit,
      calendar: calendar,
      now: start.addingTimeInterval(30)
    )

    let interval = try XCTUnwrap(snapshot.intervals.first)
    XCTAssertEqual(interval.status, .interrupted)
    XCTAssertEqual(interval.endReason, .applicationExit)
    XCTAssertEqual(interval.endedAt, lastObservation)
    XCTAssertEqual(interval.proxyUsage, TrafficBytes(upload: 7, download: 11))
  }

  func testCounterResetStartsNewCoreSessionWithoutDuplicatingTotals() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let calendar = calendar(timeZoneSecondsFromGMT: 0)
    let start = Date(timeIntervalSince1970: 1_700_200_000)
    let ledger = SQLiteTrafficLedger(databaseURL: database)

    _ = try await ledger.prepare(calendar: calendar, now: start)
    _ = try await ledger.beginMonitoring(version: "test", at: start, calendar: calendar)
    _ = try await ledger.record(
      baseline(at: start, upload: 1_000, download: 1_000),
      calendar: calendar
    )
    _ = try await ledger.record(
      delta(
        at: start.addingTimeInterval(1),
        kernelUpload: 1_020,
        kernelDownload: 1_030,
        proxy: TrafficBytes(upload: 20, download: 30)
      ),
      calendar: calendar
    )
    _ = try await ledger.record(
      TrafficLedgerObservation(
        observedAt: start.addingTimeInterval(2),
        kernelTotal: TrafficBytes(upload: 5, download: 8),
        transition: .countersReset
      ),
      calendar: calendar
    )
    let snapshot = try await ledger.record(
      delta(
        at: start.addingTimeInterval(3),
        kernelUpload: 9,
        kernelDownload: 14,
        proxy: TrafficBytes(upload: 4, download: 6)
      ),
      calendar: calendar
    )

    XCTAssertEqual(snapshot.lifetime.proxy, TrafficBytes(upload: 24, download: 36))
  }

  func testMinuteBucketPruningDoesNotChangeLongIntervalResult() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let calendar = calendar(timeZoneSecondsFromGMT: 8 * 3_600)
    let start = Date(timeIntervalSince1970: 1_700_300_000)
    let later = try XCTUnwrap(calendar.date(byAdding: .day, value: 366, to: start))
    let ledger = SQLiteTrafficLedger(databaseURL: database)

    _ = try await ledger.prepare(calendar: calendar, now: start)
    _ = try await ledger.beginMonitoring(version: "test", at: start, calendar: calendar)
    _ = try await ledger.record(
      baseline(at: start, upload: 10, download: 20),
      calendar: calendar
    )
    var snapshot = try await ledger.startInterval(
      name: "长期任务",
      note: nil,
      at: start,
      calendar: calendar
    )
    let intervalID = try XCTUnwrap(snapshot.intervals.first?.id)
    _ = try await ledger.record(
      delta(
        at: start.addingTimeInterval(60),
        kernelUpload: 20,
        kernelDownload: 40,
        proxy: TrafficBytes(upload: 10, download: 20)
      ),
      calendar: calendar
    )
    _ = try await ledger.record(
      delta(
        at: later,
        kernelUpload: 25,
        kernelDownload: 47,
        proxy: TrafficBytes(upload: 5, download: 7)
      ),
      calendar: calendar
    )
    snapshot = try await ledger.stopInterval(
      id: intervalID,
      at: later,
      calendar: calendar
    )

    XCTAssertEqual(
      snapshot.intervals.first?.proxyUsage,
      TrafficBytes(upload: 15, download: 27)
    )
    XCTAssertEqual(try minuteBucketCount(in: database), 1)
  }

  func testClearRemovesLedgerAndIntervalsWithoutSecretInput() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let calendar = calendar(timeZoneSecondsFromGMT: 0)
    let start = Date(timeIntervalSince1970: 1_700_400_000)
    let ledger = SQLiteTrafficLedger(databaseURL: database)

    _ = try await ledger.prepare(calendar: calendar, now: start)
    _ = try await ledger.beginMonitoring(version: "test", at: start, calendar: calendar)
    _ = try await ledger.record(
      baseline(at: start, upload: 100, download: 200),
      calendar: calendar
    )
    _ = try await ledger.startInterval(
      name: "不含敏感信息",
      note: nil,
      at: start,
      calendar: calendar
    )
    _ = try await ledger.record(
      delta(
        at: start.addingTimeInterval(1),
        kernelUpload: 110,
        kernelDownload: 220,
        proxy: TrafficBytes(upload: 10, download: 20)
      ),
      calendar: calendar
    )

    let snapshot = try await ledger.clear(calendar: calendar, now: start.addingTimeInterval(2))
    XCTAssertEqual(snapshot.today, .zero)
    XCTAssertEqual(snapshot.lifetime, .zero)
    XCTAssertTrue(snapshot.intervals.isEmpty)
    XCTAssertEqual(snapshot.recentProxyDays.count, 30)
    XCTAssertTrue(snapshot.recentProxyDays.allSatisfy { $0.bytes == .zero })
    XCTAssertNil(snapshot.lastObservedAt)

    let afterFreshBaseline = try await ledger.record(
      delta(
        at: start.addingTimeInterval(3),
        kernelUpload: 120,
        kernelDownload: 240,
        proxy: TrafficBytes(upload: 10, download: 20)
      ),
      calendar: calendar
    )
    XCTAssertEqual(afterFreshBaseline.lifetime, .zero)

    let afterNewDelta = try await ledger.record(
      delta(
        at: start.addingTimeInterval(4),
        kernelUpload: 123,
        kernelDownload: 245,
        proxy: TrafficBytes(upload: 3, download: 5)
      ),
      calendar: calendar
    )
    XCTAssertEqual(afterNewDelta.lifetime.proxy, TrafficBytes(upload: 3, download: 5))
    XCTAssertTrue(FileManager.default.fileExists(atPath: database.path))
    for file in databaseFiles(database) where FileManager.default.fileExists(atPath: file.path) {
      let contents = try Data(contentsOf: file)
      XCTAssertNil(String(data: contents, encoding: .utf8)?.range(of: "controller-secret"))
    }
  }

}
