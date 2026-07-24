import XCTest

@testable import MihomoMeter

final class TrafficMeasurementSessionTests: XCTestCase {
  func testProducesActiveLeavesAndRateWindowFromConfiguredCatalog() {
    let clock = ContinuousClock()
    let startedAt = clock.now
    var session = TrafficMeasurementSession()
    session.configure(
      catalog: ProxyCatalog(
        typesByName: [
          "DIRECT": "Direct",
          "Proxy Node": "VLESS",
        ]
      )
    )

    let initial = snapshot(
      kernelUpload: 100,
      kernelDownload: 200,
      proxyUpload: 40,
      proxyDownload: 80,
      directUpload: 10,
      directDownload: 20
    )
    let next = snapshot(
      kernelUpload: 200,
      kernelDownload: 400,
      proxyUpload: 80,
      proxyDownload: 160,
      directUpload: 20,
      directDownload: 40
    )

    let initialResult = session.consume(initial, at: startedAt)
    let nextResult = session.consume(
      next,
      at: startedAt.advanced(by: .seconds(1))
    )

    XCTAssertEqual(initialResult?.activeProxyLeaves, ["Proxy Node"])
    XCTAssertEqual(initialResult?.activeRuleTypes, ["DOMAIN", "MATCH"])
    XCTAssertFalse(initialResult?.requiresCatalogRefresh ?? true)
    XCTAssertNil(initialResult?.rateWindow)
    XCTAssertEqual(
      nextResult?.rateWindow?.raw.proxy,
      TrafficRate(
        uploadBytesPerSecond: 40,
        downloadBytesPerSecond: 80
      )
    )
    XCTAssertEqual(
      nextResult?.rateWindow?.raw.direct,
      TrafficRate(
        uploadBytesPerSecond: 10,
        downloadBytesPerSecond: 20
      )
    )
  }

  func testReportsMissingCatalogEntryWithoutGuessingProxy() {
    var session = TrafficMeasurementSession()
    session.configure(catalog: ProxyCatalog(typesByName: [:]))

    let result = session.consume(
      ConnectionTrafficSnapshot(
        kernelTotal: .zero,
        connections: [
          ConnectionTrafficSample(
            id: "connection-1",
            bytes: .zero,
            chains: ["Unknown Node"]
          )
        ]
      )
    )

    XCTAssertTrue(result?.requiresCatalogRefresh ?? false)
    XCTAssertEqual(result?.activeProxyLeaves, [])
  }

  private func snapshot(
    kernelUpload: UInt64,
    kernelDownload: UInt64,
    proxyUpload: UInt64,
    proxyDownload: UInt64,
    directUpload: UInt64,
    directDownload: UInt64
  ) -> ConnectionTrafficSnapshot {
    ConnectionTrafficSnapshot(
      kernelTotal: TrafficBytes(
        upload: kernelUpload,
        download: kernelDownload
      ),
      connections: [
        ConnectionTrafficSample(
          id: "proxy-connection",
          bytes: TrafficBytes(
            upload: proxyUpload,
            download: proxyDownload
          ),
          chains: ["Proxy Node"],
          rule: "DOMAIN"
        ),
        ConnectionTrafficSample(
          id: "direct-connection",
          bytes: TrafficBytes(
            upload: directUpload,
            download: directDownload
          ),
          chains: ["DIRECT"],
          rule: "MATCH"
        ),
      ]
    )
  }
}
