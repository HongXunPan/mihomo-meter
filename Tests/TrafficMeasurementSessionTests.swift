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
      at: startedAt.advanced(by: .seconds(1)),
      observedAt: Date(timeIntervalSince1970: 1_700_000_001)
    )

    XCTAssertEqual(initialResult?.activeProxyLeaves, ["Proxy Node"])
    XCTAssertEqual(initialResult?.activeRuleTypes, ["DOMAIN", "MATCH"])
    XCTAssertFalse(initialResult?.requiresCatalogRefresh ?? true)
    XCTAssertNil(initialResult?.rateWindow)
    XCTAssertEqual(
      initialResult?.ledgerObservation.transition,
      .baselineEstablished
    )
    XCTAssertEqual(
      nextResult?.ledgerObservation,
      TrafficLedgerObservation(
        observedAt: Date(timeIntervalSince1970: 1_700_000_001),
        kernelTotal: next.kernelTotal,
        transition: .delta(
          TrafficDeltaReport(
            kernel: TrafficBytes(upload: 100, download: 200),
            categories: CategorizedTrafficBytes(
              proxy: TrafficBytes(upload: 40, download: 80),
              direct: TrafficBytes(upload: 10, download: 20),
              reject: .zero,
              unknown: TrafficBytes(upload: 50, download: 100)
            )
          )
        )
      )
    )
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

  func testExposesCounterResetForLedgerWithoutProducingRate() {
    let clock = ContinuousClock()
    var session = TrafficMeasurementSession()
    session.configure(catalog: ProxyCatalog(typesByName: [:]))

    _ = session.consume(
      ConnectionTrafficSnapshot(
        kernelTotal: TrafficBytes(upload: 100, download: 200),
        connections: []
      ),
      at: clock.now
    )
    let result = session.consume(
      ConnectionTrafficSnapshot(
        kernelTotal: TrafficBytes(upload: 10, download: 20),
        connections: []
      ),
      at: clock.now.advanced(by: .seconds(1))
    )

    XCTAssertEqual(result?.ledgerObservation.transition, .countersReset)
    XCTAssertNil(result?.rateWindow)
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
