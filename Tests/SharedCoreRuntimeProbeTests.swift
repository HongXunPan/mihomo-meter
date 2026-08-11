import XCTest

@testable import MihomoMeter

final class SharedCoreRuntimeProbeTests: XCTestCase {
  func testProductionRuntimeProbeLoadsSharedCore() {
    XCTAssertEqual(SharedCoreRuntimeProbe.run(), .ready)
  }

  func testRuntimeProbeStopsBeforeNativeCallForABIMismatch() {
    var didScaleTraffic = false

    let status = SharedCoreRuntimeProbe.run(
      abiVersion: { 2 },
      scaleTraffic: { _ in
        didScaleTraffic = true
        return SharedTrafficScale(
          value: 1.5,
          unit: .kilobytes,
          decimalPlaces: 2
        )
      }
    )

    XCTAssertEqual(status, .abiMismatch)
    XCTAssertFalse(didScaleTraffic)
  }

  func testRuntimeProbeMapsAdapterFailureWithoutThrowing() {
    let status = SharedCoreRuntimeProbe.run(
      abiVersion: { 1 },
      scaleTraffic: { _ in
        throw SharedCoreAdapterError.nativeCallFailed(-1)
      }
    )

    XCTAssertEqual(status, .nativeCallFailed)
  }

  func testRuntimeProbeRejectsUnexpectedResult() {
    let status = SharedCoreRuntimeProbe.run(
      abiVersion: { 1 },
      scaleTraffic: { _ in
        SharedTrafficScale(
          value: 1.5,
          unit: .megabytes,
          decimalPlaces: 2
        )
      }
    )

    XCTAssertEqual(status, .unexpectedResult)
  }
}
