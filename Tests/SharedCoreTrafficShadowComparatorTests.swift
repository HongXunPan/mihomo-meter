import XCTest

@testable import MihomoMeter

final class SharedCoreTrafficShadowComparatorTests: XCTestCase {
  func testComparatorMatchesAllProductionFormats() {
    let scaleTraffic: (UInt64) throws -> SharedTrafficScale = { _ in
      SharedTrafficScale(
        value: 1.5,
        unit: .kilobytes,
        decimalPlaces: 2
      )
    }

    XCTAssertEqual(
      SharedCoreTrafficShadowComparator.compare(
        bytes: 1_500,
        nativeText: "1.50 KB",
        format: .byteCount,
        scaleTraffic: scaleTraffic
      ),
      .matched
    )
    XCTAssertEqual(
      SharedCoreTrafficShadowComparator.compare(
        bytes: 1_500,
        nativeText: "1.50 KB/s",
        format: .rate,
        scaleTraffic: scaleTraffic
      ),
      .matched
    )
    XCTAssertEqual(
      SharedCoreTrafficShadowComparator.compare(
        bytes: 1_500,
        nativeText: "1.50K/s",
        format: .compactRate,
        scaleTraffic: scaleTraffic
      ),
      .matched
    )
  }

  func testComparatorReportsMismatchWithoutChangingNativeText() {
    let status = SharedCoreTrafficShadowComparator.compare(
      bytes: 1_500,
      nativeText: "原生输出",
      format: .byteCount,
      scaleTraffic: { _ in
        SharedTrafficScale(
          value: 1.5,
          unit: .kilobytes,
          decimalPlaces: 2
        )
      }
    )

    XCTAssertEqual(status, .mismatch)
  }

  func testComparatorMapsAdapterFailuresToCoarseStatuses() {
    XCTAssertEqual(
      compareThrowing(.unsupportedABIVersion(2)),
      .abiMismatch
    )
    XCTAssertEqual(
      compareThrowing(.nativeCallFailed(-1)),
      .nativeCallFailed
    )
    XCTAssertEqual(
      compareThrowing(.unsupportedTrafficUnit(99)),
      .unsupportedTrafficUnit
    )
  }

  func testComparatorRejectsUnsupportedDecimalPlaces() {
    let status = SharedCoreTrafficShadowComparator.compare(
      bytes: 1_500,
      nativeText: "1.50 KB",
      format: .byteCount,
      scaleTraffic: { _ in
        SharedTrafficScale(
          value: 1.5,
          unit: .kilobytes,
          decimalPlaces: 3
        )
      }
    )

    XCTAssertEqual(status, .unexpectedResult)
  }

  func testObservationGateReportsEachFormatAndStatusOnce() {
    var gate = SharedCoreTrafficShadowObservationGate()
    let byteCountMatched = SharedCoreTrafficShadowObservation(
      format: .byteCount,
      status: .matched
    )

    XCTAssertTrue(gate.shouldReport(byteCountMatched))
    XCTAssertFalse(gate.shouldReport(byteCountMatched))
    XCTAssertTrue(
      gate.shouldReport(
        SharedCoreTrafficShadowObservation(
          format: .byteCount,
          status: .mismatch
        )
      )
    )
    XCTAssertTrue(
      gate.shouldReport(
        SharedCoreTrafficShadowObservation(
          format: .rate,
          status: .matched
        )
      )
    )

    gate.reset()
    XCTAssertTrue(gate.shouldReport(byteCountMatched))
  }

  private func compareThrowing(
    _ error: SharedCoreAdapterError
  ) -> SharedCoreTrafficShadowStatus {
    SharedCoreTrafficShadowComparator.compare(
      bytes: 1_500,
      nativeText: "1.50 KB",
      format: .byteCount,
      scaleTraffic: { _ in throw error }
    )
  }
}
