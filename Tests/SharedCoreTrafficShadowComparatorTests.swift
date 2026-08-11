import XCTest
import os

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

  func testRouterReturnsSharedTextOnlyForExactMatch() {
    let result = SharedCoreTrafficRouter.route(
      bytes: 1_500,
      nativeText: "1.50 KB",
      format: .byteCount,
      scaleTraffic: { _ in
        SharedTrafficScale(
          value: 1.5,
          unit: .kilobytes,
          decimalPlaces: 2
        )
      }
    )

    XCTAssertEqual(result.text, "1.50 KB")
    XCTAssertEqual(result.source, .sharedPrimary)
    XCTAssertEqual(result.status, .matched)
  }

  func testRouterFallsBackToNativeTextForMismatchAndSharedFailures() {
    let mismatch = SharedCoreTrafficRouter.route(
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
    let abiMismatch = routeThrowing(.unsupportedABIVersion(2))
    let nativeCallFailed = routeThrowing(.nativeCallFailed(-1))
    let unsupportedUnit = routeThrowing(.unsupportedTrafficUnit(99))
    let unexpectedResult = SharedCoreTrafficRouter.route(
      bytes: 1_500,
      nativeText: "原生输出",
      format: .byteCount,
      scaleTraffic: { _ in
        SharedTrafficScale(
          value: 1.5,
          unit: .kilobytes,
          decimalPlaces: 3
        )
      }
    )
    let unknownFailure = routeThrowing(SyntheticError())

    XCTAssertEqual(mismatch.text, "原生输出")
    XCTAssertEqual(mismatch.source, .nativeFallback)
    XCTAssertEqual(mismatch.status, .mismatch)
    XCTAssertEqual(abiMismatch.status, .abiMismatch)
    XCTAssertEqual(nativeCallFailed.status, .nativeCallFailed)
    XCTAssertEqual(unsupportedUnit.status, .unsupportedTrafficUnit)
    XCTAssertEqual(unexpectedResult.status, .unexpectedResult)
    XCTAssertEqual(unknownFailure.status, .unknownFailure)
    XCTAssertTrue(
      [abiMismatch, nativeCallFailed, unsupportedUnit, unexpectedResult, unknownFailure]
        .allSatisfy {
          $0.text == "原生输出" && $0.source == .nativeFallback
        }
    )
  }

  func testShadowAlwaysReturnsNativeTextWithInjectedSharedCandidate() {
    let text = SharedCoreTrafficShadow.observe(
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

    XCTAssertEqual(text, "原生输出")
  }

  func testRouteDeduplicatesObservationsAndIgnoresReporterFailure() {
    let observations = OSAllocatedUnfairLock(
      initialState: [SharedCoreTrafficRouteObservation]()
    )
    SharedCoreTrafficRoute.configure { observation in
      observations.withLock { $0.append(observation) }
      throw SyntheticError()
    }
    defer {
      SharedCoreTrafficRoute.configure(reporter: nil)
    }

    let firstText = resolveMatchingRoute()
    let secondText = resolveMatchingRoute()

    XCTAssertEqual(firstText, "1.50 KB")
    XCTAssertEqual(secondText, "1.50 KB")
    XCTAssertEqual(
      observations.withLock { $0 },
      [
        SharedCoreTrafficRouteObservation(
          format: .byteCount,
          source: .sharedPrimary,
          status: .matched
        )
      ]
    )
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

  private func routeThrowing(
    _ error: any Error
  ) -> SharedCoreTrafficRouteResult {
    SharedCoreTrafficRouter.route(
      bytes: 1_500,
      nativeText: "原生输出",
      format: .byteCount,
      scaleTraffic: { _ in throw error }
    )
  }

  private func resolveMatchingRoute() -> String {
    SharedCoreTrafficRoute.resolve(
      bytes: 1_500,
      nativeText: "1.50 KB",
      format: .byteCount,
      scaleTraffic: { _ in
        SharedTrafficScale(
          value: 1.5,
          unit: .kilobytes,
          decimalPlaces: 2
        )
      }
    )
  }
}

private struct SyntheticError: Error {}
