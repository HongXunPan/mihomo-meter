import XCTest

@testable import MihomoMeter

final class LiveConnectionAnalyticsPresentationTests: XCTestCase {
  @MainActor
  func testWorkspaceSelectionOpensRequestedLiveConnectionRoute() {
    let model = StatisticsWorkspaceModel()

    model.selectLiveConnections(route: .direct)

    XCTAssertEqual(model.selectedModule, .proxyTraffic)
    XCTAssertEqual(model.selectedProxyTrafficSection, .liveConnections)
    XCTAssertEqual(model.selectedLiveConnectionRoute, .direct)
  }

  func testRouteSelectionKeepsProxyAndDirectConnectionsSeparated() {
    let proxyConnections = [
      connection(id: "proxy", application: "Browser", hostname: "proxy.example")
    ]
    let directConnections = [
      connection(id: "direct", application: "Updater", hostname: "direct.example")
    ]

    XCTAssertEqual(
      LiveConnectionAnalyticsPresentation.sourceConnections(
        for: .proxy,
        proxyConnections: proxyConnections,
        directConnections: directConnections
      ).map(\.id),
      ["proxy"]
    )
    XCTAssertEqual(
      LiveConnectionAnalyticsPresentation.sourceConnections(
        for: .direct,
        proxyConnections: proxyConnections,
        directConnections: directConnections
      ).map(\.id),
      ["direct"]
    )
  }

  func testSearchMatchesApplicationAndHostnameCaseInsensitively() {
    let connections = [
      connection(id: "browser", application: "Browser", hostname: "docs.example"),
      connection(id: "download", application: "Downloader", hostname: "files.example"),
    ]

    XCTAssertEqual(
      LiveConnectionAnalyticsPresentation.connections(
        from: connections,
        searchText: "BROWSER"
      ).map(\.id),
      ["browser"]
    )
    XCTAssertEqual(
      LiveConnectionAnalyticsPresentation.connections(
        from: connections,
        searchText: "FILES"
      ).map(\.id),
      ["download"]
    )
  }

  func testApplicationGroupsSumRatesAndActiveCumulativeBytes() throws {
    let connections = [
      connection(
        id: "first",
        application: "Browser",
        hostname: "a.example",
        upload: 10,
        download: 20,
        cumulative: 100
      ),
      connection(
        id: "second",
        application: "Browser",
        hostname: "b.example",
        upload: 30,
        download: 40,
        cumulative: 200
      ),
    ]

    let row = try XCTUnwrap(
      LiveConnectionAnalyticsPresentation.groups(
        from: connections,
        mode: .application,
        searchText: ""
      ).first
    )

    XCTAssertEqual(row.name, "Browser")
    XCTAssertEqual(row.relatedCount, 2)
    XCTAssertEqual(row.connectionCount, 2)
    XCTAssertEqual(row.rate.uploadBytesPerSecond, 40)
    XCTAssertEqual(row.rate.downloadBytesPerSecond, 60)
    XCTAssertEqual(row.cumulativeBytes.total, 300)
  }

  func testHostnameGroupsKeepUnknownApplicationAsRelatedItem() throws {
    let connections = [
      connection(id: "known", application: "Browser", hostname: "a.example"),
      connection(id: "unknown", application: nil, hostname: "a.example"),
    ]

    let row = try XCTUnwrap(
      LiveConnectionAnalyticsPresentation.groups(
        from: connections,
        mode: .hostname,
        searchText: ""
      ).first
    )

    XCTAssertEqual(row.name, "a.example")
    XCTAssertEqual(row.relatedCount, 2)
    XCTAssertEqual(row.connectionCount, 2)
  }

  func testProcessMatchingDiagnosticOnlyExpandsOffAndUnavailableModes() {
    let coverage = ConnectionAttributionCoverage(
      proxyConnectionCount: 46,
      hostnameIdentifiedCount: 46,
      applicationIdentifiedCount: 38,
      fullyIdentifiedCount: 38
    )

    let always = ApplicationIdentificationDiagnostic(mode: .always, coverage: coverage)
    let strict = ApplicationIdentificationDiagnostic(mode: .strict, coverage: coverage)
    let off = ApplicationIdentificationDiagnostic(mode: .off, coverage: coverage)
    let unavailable = ApplicationIdentificationDiagnostic(mode: nil, coverage: coverage)

    XCTAssertFalse(always.shouldShowDetail)
    XCTAssertFalse(strict.shouldShowDetail)
    XCTAssertEqual(off.title, "进程识别 off · 38/46")
    XCTAssertTrue(off.isWarning)
    XCTAssertTrue(off.shouldShowDetail)
    XCTAssertTrue(off.detail.contains("已关闭"))
    XCTAssertEqual(unavailable.title, "进程识别不可确认 · 38/46")
    XCTAssertFalse(unavailable.isWarning)
    XCTAssertTrue(unavailable.shouldShowDetail)
  }

  private func connection(
    id: String,
    application: String?,
    hostname: String?,
    upload: UInt64 = 0,
    download: UInt64 = 0,
    cumulative: UInt64 = 0
  ) -> LiveTrafficConnection {
    LiveTrafficConnection(
      id: id,
      metadata: ConnectionMetadata(hostname: hostname, applicationName: application),
      rate: TrafficRate(
        uploadBytesPerSecond: upload,
        downloadBytesPerSecond: download
      ),
      cumulativeBytes: TrafficBytes(upload: cumulative, download: 0),
      startedAt: nil
    )
  }
}
