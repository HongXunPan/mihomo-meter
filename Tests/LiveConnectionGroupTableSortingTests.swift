import XCTest

@testable import MihomoMeter

final class LiveConnectionGroupTableSortingTests: XCTestCase {
  func testGroupColumnsSortRawValuesAndResetToIncomingOrder() {
    let rows = [
      row(name: "Alpha", related: 2, connections: 3, download: 30, upload: 10, cumulative: 100),
      row(name: "Beta", related: 4, connections: 1, download: 10, upload: 20, cumulative: 200),
      row(name: "Gamma", related: 1, connections: 2, download: 20, upload: 30, cumulative: 300),
    ]

    XCTAssertEqual(names(rows, column: nil, ascending: false), ["Alpha", "Beta", "Gamma"])
    XCTAssertEqual(names(rows, column: .name, ascending: false), ["Gamma", "Beta", "Alpha"])
    XCTAssertEqual(
      names(rows, column: .relatedCount, ascending: false), ["Beta", "Alpha", "Gamma"])
    XCTAssertEqual(
      names(rows, column: .connectionCount, ascending: true), ["Beta", "Gamma", "Alpha"])
    XCTAssertEqual(names(rows, column: .download, ascending: false), ["Alpha", "Gamma", "Beta"])
    XCTAssertEqual(names(rows, column: .upload, ascending: false), ["Gamma", "Beta", "Alpha"])
    XCTAssertEqual(names(rows, column: .cumulative, ascending: true), ["Alpha", "Beta", "Gamma"])
  }

  func testClearingSearchRestoresAllCurrentGroupsWithoutChangingDefaultOrder() {
    let connections = [
      connection(id: "alpha", application: "Alpha", hostname: "alpha.example", download: 30),
      connection(id: "beta", application: "Beta", hostname: "beta.example", download: 10),
    ]
    let matched = LiveConnectionAnalyticsPresentation.groups(
      from: connections,
      mode: .application,
      searchText: "alpha.example"
    )
    let restored = LiveConnectionAnalyticsPresentation.groups(
      from: connections,
      mode: .application,
      searchText: ""
    )

    XCTAssertEqual(matched.map(\.name), ["Alpha"])
    XCTAssertEqual(restored.map(\.name), ["Alpha", "Beta"])
    XCTAssertEqual(
      LiveConnectionTableSorting.groups(restored, column: nil, ascending: false).map(\.name),
      ["Alpha", "Beta"]
    )
  }

  func testNameAndRelatedTitlesFollowSelectedDimension() {
    XCTAssertEqual(LiveConnectionGroupTableColumn.name.title(for: .application), "应用")
    XCTAssertEqual(LiveConnectionGroupTableColumn.name.title(for: .hostname), "域名")
    XCTAssertEqual(LiveConnectionGroupTableColumn.relatedCount.title(for: .application), "域名数")
    XCTAssertEqual(LiveConnectionGroupTableColumn.relatedCount.title(for: .hostname), "应用数")
  }

  private func names(
    _ rows: [LiveConnectionGroupRow],
    column: LiveConnectionGroupTableColumn?,
    ascending: Bool
  ) -> [String] {
    LiveConnectionTableSorting.groups(rows, column: column, ascending: ascending).map(\.name)
  }

  private func row(
    name: String,
    related: Int,
    connections: Int,
    download: UInt64,
    upload: UInt64,
    cumulative: UInt64
  ) -> LiveConnectionGroupRow {
    LiveConnectionGroupRow(
      mode: .application,
      name: name,
      relatedCount: related,
      connectionCount: connections,
      rate: TrafficRate(uploadBytesPerSecond: upload, downloadBytesPerSecond: download),
      cumulativeBytes: TrafficBytes(upload: cumulative, download: 0)
    )
  }

  private func connection(
    id: String,
    application: String,
    hostname: String,
    download: UInt64
  ) -> LiveTrafficConnection {
    LiveTrafficConnection(
      id: id,
      metadata: ConnectionMetadata(hostname: hostname, applicationName: application),
      rate: TrafficRate(uploadBytesPerSecond: 0, downloadBytesPerSecond: download),
      cumulativeBytes: .zero,
      startedAt: nil
    )
  }
}
