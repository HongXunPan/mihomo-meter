import XCTest

@testable import MihomoMeter

final class ConnectionAnalyticsPresentationTests: XCTestCase {
  func testTopConnectionsExcludesZeroRateAndSortsByCombinedRate() {
    let connections = [
      connection(id: "zero", hostname: "zero.example", upload: 0, download: 0),
      connection(id: "second", hostname: "b.example", upload: 10, download: 20),
      connection(id: "first", hostname: "a.example", upload: 20, download: 30),
    ]

    let result = ConnectionAnalyticsPresentation.topConnections(from: connections)

    XCTAssertEqual(result.map(\.id), ["first", "second"])
  }

  func testTopConnectionSlotsAlwaysReserveFivePositions() {
    let connections = [
      connection(id: "zero", hostname: "zero.example", upload: 0, download: 0),
      connection(id: "second", hostname: "b.example", upload: 10, download: 20),
      connection(id: "first", hostname: "a.example", upload: 20, download: 30),
    ]

    let slots = ConnectionAnalyticsPresentation.topConnectionSlots(from: connections)

    XCTAssertEqual(slots.count, 5)
    XCTAssertEqual(slots.compactMap(\.self).map(\.id), ["first", "second"])
    XCTAssertEqual(
      ConnectionAnalyticsPresentation.activeConnectionCount(from: connections),
      2
    )
    XCTAssertEqual(
      ConnectionAnalyticsPresentation.activeConnectionSummary(from: connections),
      "2 条活跃"
    )
    XCTAssertEqual(
      ConnectionAnalyticsPresentation.activeConnectionSummary(from: []),
      "暂无传输"
    )
  }

  func testTrendTargetsInheritTheOppositeDimensionFilter() {
    let applicationTarget = ConnectionAnalyticsPresentation.applicationTrendTarget(
      applicationName: "Codex",
      selectedHostname: "example.com"
    )
    let hostnameTarget = ConnectionAnalyticsPresentation.hostnameTrendTarget(
      hostname: ConnectionAttributionLabel.unknownHostname,
      selectedApplication: ConnectionAttributionLabel.unknownApplication
    )

    XCTAssertEqual(applicationTarget.query.applicationName, "Codex")
    XCTAssertEqual(applicationTarget.query.hostname, "example.com")
    XCTAssertEqual(applicationTarget.inheritedFilterDescription, "域名：example.com")
    XCTAssertEqual(hostnameTarget.query.hostname, ConnectionAttributionLabel.unknownHostname)
    XCTAssertEqual(
      hostnameTarget.query.applicationName,
      ConnectionAttributionLabel.unknownApplication
    )
    XCTAssertEqual(hostnameTarget.inheritedFilterDescription, "应用：未知应用")
  }

  func testRankingsApplyApplicationAndHostnameCrossFilter() {
    let records = [
      record(application: "Browser", hostname: "a.example", total: 10),
      record(application: "Browser", hostname: "b.example", total: 20),
      record(application: "Downloader", hostname: "a.example", total: 30),
    ]

    let applications = ConnectionAnalyticsPresentation.applicationRanking(
      records: records,
      application: nil,
      hostname: "a.example"
    )
    let hostnames = ConnectionAnalyticsPresentation.hostnameRanking(
      records: records,
      application: "Browser",
      hostname: nil
    )

    XCTAssertEqual(applications.map(\.name), ["Downloader", "Browser"])
    XCTAssertEqual(hostnames.map(\.name), ["b.example", "a.example"])
  }

  private func connection(
    id: String,
    hostname: String,
    upload: UInt64,
    download: UInt64
  ) -> LiveProxyConnection {
    LiveProxyConnection(
      id: id,
      metadata: ConnectionMetadata(hostname: hostname, applicationName: "Example"),
      rate: TrafficRate(
        uploadBytesPerSecond: upload,
        downloadBytesPerSecond: download
      ),
      cumulativeBytes: .zero,
      startedAt: nil
    )
  }

  private func record(
    application: String,
    hostname: String,
    total: UInt64
  ) -> ConnectionAttributionRecord {
    ConnectionAttributionRecord(
      localDay: "2026-07-30",
      applicationName: application,
      hostname: hostname,
      bytes: TrafficBytes(upload: total, download: 0)
    )
  }
}
