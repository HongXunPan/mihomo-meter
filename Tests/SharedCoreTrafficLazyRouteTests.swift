import XCTest
import os

@testable import MihomoMeter

final class SharedCoreTrafficLazyRouteTests: XCTestCase {
  func testLazyRouterDoesNotEvaluateFallbackOnSuccess() {
    var fallbackCount = 0

    let result = SharedCoreTrafficRouter.routeLazy(
      bytes: 1_500,
      nativeFallback: {
        fallbackCount += 1
        return "原生回退"
      },
      format: .byteCount,
      abiVersion: { 1 },
      scaleTraffic: { _ in matchingScale() }
    )

    XCTAssertEqual(result.text, "1.50 KB")
    XCTAssertEqual(result.source, .sharedPrimary)
    XCTAssertEqual(result.status, .succeeded)
    XCTAssertEqual(fallbackCount, 0)
  }

  func testLazyRouterStopsBeforeScalingForABIMismatch() {
    var scaleCount = 0

    assertLazyFallback(
      expectedStatus: .abiMismatch,
      abiVersion: { 2 },
      scaleTraffic: { _ in
        scaleCount += 1
        return matchingScale()
      }
    )

    XCTAssertEqual(scaleCount, 0)
  }

  func testLazyRouterEvaluatesFallbackExactlyOnceForSharedFailures() {
    assertLazyFallback(expectedStatus: .nativeCallFailed) { _ in
      throw SharedCoreAdapterError.nativeCallFailed(-1)
    }
    assertLazyFallback(expectedStatus: .abiMismatch) { _ in
      throw SharedCoreAdapterError.unsupportedABIVersion(2)
    }
    assertLazyFallback(expectedStatus: .unexpectedResult) { _ in
      throw SharedCoreAdapterError.unsupportedTrafficUnit(99)
    }
    assertLazyFallback(expectedStatus: .unexpectedResult) { _ in
      SharedTrafficScale(value: 1.5, unit: .kilobytes, decimalPlaces: 3)
    }
    assertLazyFallback(expectedStatus: .unknownFailure) { _ in
      throw LazyRouteSyntheticError()
    }
  }

  func testLazyRouteIgnoresReporterFailureWithoutEvaluatingFallback() {
    let observations = OSAllocatedUnfairLock(
      initialState: [SharedCoreTrafficRouteObservation]()
    )
    var fallbackCount = 0
    SharedCoreTrafficRoute.configure { observation in
      observations.withLock { $0.append(observation) }
      throw LazyRouteSyntheticError()
    }
    defer {
      SharedCoreTrafficRoute.configure(reporter: nil)
    }

    for _ in 0..<2 {
      let text = SharedCoreTrafficRoute.resolveLazy(
        bytes: 1_500,
        nativeFallback: {
          fallbackCount += 1
          return "原生回退"
        },
        format: .byteCount,
        abiVersion: { 1 },
        scaleTraffic: { _ in matchingScale() }
      )
      XCTAssertEqual(text, "1.50 KB")
    }

    XCTAssertEqual(fallbackCount, 0)
    XCTAssertEqual(
      observations.withLock { $0 },
      [
        SharedCoreTrafficRouteObservation(
          format: .byteCount,
          source: .sharedPrimary,
          status: .succeeded
        )
      ]
    )
  }

  func testDeterministicDifferentialMatchesNativeFormatters() throws {
    var values = deterministicBoundaryValues()
    var generator = SplitMix64(seed: 0x4D49_484F_4D45_5445)
    for _ in 0..<10_000 {
      values.append(generator.next())
    }

    for bytes in values {
      let scale = try MihomoMeterSharedCoreAdapter.scaleTraffic(bytes: bytes)
      XCTAssertEqual(
        TrafficStatisticsFormatter.nativeBytes(bytes),
        try SharedCoreTrafficDisplayFormatter.string(from: scale, format: .byteCount),
        "累计流量差分不一致：\(bytes)"
      )
      XCTAssertEqual(
        TrafficRateFormatter.nativeString(from: bytes),
        try SharedCoreTrafficDisplayFormatter.string(from: scale, format: .rate),
        "完整速率差分不一致：\(bytes)"
      )
      XCTAssertEqual(
        TrafficRateFormatter.nativeCompactString(from: bytes),
        try SharedCoreTrafficDisplayFormatter.string(from: scale, format: .compactRate),
        "紧凑速率差分不一致：\(bytes)"
      )
    }
  }

  private func assertLazyFallback(
    expectedStatus: SharedCoreTrafficRouteStatus,
    abiVersion: () -> UInt32 = { 1 },
    scaleTraffic: (UInt64) throws -> SharedTrafficScale,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    var fallbackCount = 0
    let result = SharedCoreTrafficRouter.routeLazy(
      bytes: 1_500,
      nativeFallback: {
        fallbackCount += 1
        return "原生回退"
      },
      format: .byteCount,
      abiVersion: abiVersion,
      scaleTraffic: scaleTraffic
    )

    XCTAssertEqual(result.text, "原生回退", file: file, line: line)
    XCTAssertEqual(result.source, .nativeFallback, file: file, line: line)
    XCTAssertEqual(result.status, expectedStatus, file: file, line: line)
    XCTAssertEqual(fallbackCount, 1, file: file, line: line)
  }

  private func matchingScale() -> SharedTrafficScale {
    SharedTrafficScale(value: 1.5, unit: .kilobytes, decimalPlaces: 2)
  }

  private func deterministicBoundaryValues() -> [UInt64] {
    var values: Set<UInt64> = [0, .max]
    let decimalUnits: [UInt64] = [1_000, 1_000_000, 1_000_000_000, 1_000_000_000_000]

    for unit in decimalUnits {
      appendNeighborhood(around: unit, to: &values)
      appendNeighborhood(around: unit * 10, to: &values)
      appendNeighborhood(around: unit * 100, to: &values)
      appendNeighborhood(around: unit + unit * 5 / 1_000, to: &values)
      appendNeighborhood(around: unit * 9 + unit * 995 / 1_000, to: &values)
      appendNeighborhood(around: unit * 10 + unit * 5 / 100, to: &values)
      appendNeighborhood(around: unit * 99 + unit * 95 / 100, to: &values)
      appendNeighborhood(around: unit * 100 + unit / 2, to: &values)
      appendNeighborhood(around: unit * 999 + unit / 2, to: &values)
    }

    return values.sorted()
  }

  private func appendNeighborhood(
    around center: UInt64,
    to values: inout Set<UInt64>
  ) {
    for distance in UInt64(0)...2 {
      values.insert(center + distance)
      if center >= distance {
        values.insert(center - distance)
      }
    }
  }
}

private struct SplitMix64 {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return value ^ (value >> 31)
  }
}

private struct LazyRouteSyntheticError: Error {}
