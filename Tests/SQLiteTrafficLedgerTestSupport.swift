import Foundation
import SQLite3
import XCTest

@testable import MihomoMeter

class SQLiteTrafficLedgerTestCase: XCTestCase {
  func temporaryDatabase() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("MihomoMeterTests-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("traffic.sqlite3")
  }

  func removeDatabase(at url: URL) {
    try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
  }

  func calendar(timeZoneSecondsFromGMT seconds: Int) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: seconds) ?? .gmt
    return calendar
  }

  func baseline(
    at date: Date,
    upload: UInt64,
    download: UInt64
  ) -> TrafficLedgerObservation {
    TrafficLedgerObservation(
      observedAt: date,
      kernelTotal: TrafficBytes(upload: upload, download: download),
      transition: .baselineEstablished
    )
  }

  func delta(
    at date: Date,
    kernelUpload: UInt64,
    kernelDownload: UInt64,
    proxy: TrafficBytes
  ) -> TrafficLedgerObservation {
    TrafficLedgerObservation(
      observedAt: date,
      kernelTotal: TrafficBytes(upload: kernelUpload, download: kernelDownload),
      transition: .delta(
        TrafficDeltaReport(
          kernel: proxy,
          categories: CategorizedTrafficBytes.zero.adding(proxy, to: .proxy)
        )
      )
    )
  }

  func minuteBucketCount(in databaseURL: URL) throws -> Int64 {
    let connection = try SQLiteConnection(fileURL: databaseURL)
    let statement = try connection.prepare("SELECT COUNT(*) FROM traffic_buckets")
    guard try statement.step() == SQLITE_ROW else {
      return 0
    }
    return statement.int64(at: 0)
  }

  func databaseFiles(_ databaseURL: URL) -> [URL] {
    [
      databaseURL,
      URL(fileURLWithPath: databaseURL.path + "-wal"),
      URL(fileURLWithPath: databaseURL.path + "-shm"),
    ]
  }
}
