import XCTest
import os

@testable import MihomoMeter

final class SharedCoreProxyTypeLazyRouteTests: XCTestCase {
  private let proxy = ProxyClassification(category: .proxy, unknownReason: nil)
  private let direct = ProxyClassification(category: .direct, unknownReason: nil)
  private let reject = ProxyClassification(category: .reject, unknownReason: nil)
  private let unknown = ProxyClassification(
    category: .unknown,
    unknownReason: .ambiguousProxyType
  )

  func testLazyRouterDoesNotEvaluateFallbackOnSharedSuccess() {
    let cases: [(SharedProxyTypeClassification, ProxyClassification)] = [
      (.proxy, proxy),
      (.direct, direct),
      (.reject, reject),
    ]

    for (sharedClassification, expectedClassification) in cases {
      var fallbackCount = 0
      var classifyCount = 0
      let result = SharedCoreProxyTypeRouter.routeLazy(
        rawType: "Synthetic",
        nativeFallback: {
          fallbackCount += 1
          return self.unknown
        },
        classifyProxyType: { _ in
          classifyCount += 1
          return sharedClassification
        }
      )

      XCTAssertEqual(result.classification, expectedClassification)
      XCTAssertEqual(result.source, .sharedPrimary)
      XCTAssertEqual(result.status, .succeeded)
      XCTAssertEqual(classifyCount, 1)
      XCTAssertEqual(fallbackCount, 0)
    }
  }

  func testLazyRouterEvaluatesFallbackExactlyOnceForUnrecognizedAndSharedFailures() {
    assertLazyFallback(expectedStatus: .unrecognized) { _ in .unrecognized }

    let failures: [(SharedProxyTypeAdapterError, SharedCoreProxyTypeRouteStatus)] = [
      (.unsupportedABIVersion(2), .abiMismatch),
      (.nativeCallFailed(-1), .nativeCallFailed),
      (.unsupportedProxyTypeInput, .unsupportedInput),
      (.proxyTypeInputTooLong, .inputTooLong),
      (.unsupportedProxyTypeCategory(99), .unexpectedResult),
    ]
    for (error, status) in failures {
      assertLazyFallback(expectedStatus: status) { _ in throw error }
    }
    assertLazyFallback(expectedStatus: .unknownFailure) { _ in
      throw SyntheticLazyRouteError()
    }
  }

  func testLazyRouteIgnoresReporterFailureWithoutEvaluatingFallback() {
    let observations = OSAllocatedUnfairLock(
      initialState: [SharedCoreProxyTypeRouteObservation]()
    )
    let fallbackCount = OSAllocatedUnfairLock(initialState: 0)
    let fallbackClassification = unknown
    let expectedClassification = proxy
    SharedCoreProxyTypeRoute.configure { observation in
      observations.withLock { $0.append(observation) }
      throw SyntheticLazyRouteError()
    }
    defer {
      SharedCoreProxyTypeRoute.configure(reporter: nil)
    }

    for _ in 0..<2 {
      let result = SharedCoreProxyTypeRoute.resolveLazy(
        rawType: "Vmess",
        nativeFallback: {
          fallbackCount.withLock { $0 += 1 }
          return fallbackClassification
        },
        classifyProxyType: { _ in .proxy }
      )
      XCTAssertEqual(result, expectedClassification)
    }

    XCTAssertEqual(fallbackCount.withLock { $0 }, 0)
    XCTAssertEqual(
      observations.withLock { $0 },
      [
        SharedCoreProxyTypeRouteObservation(
          source: .sharedPrimary,
          status: .succeeded
        )
      ]
    )
  }

  private func assertLazyFallback(
    expectedStatus: SharedCoreProxyTypeRouteStatus,
    classifyProxyType: (String) throws -> SharedProxyTypeClassification,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    var fallbackCount = 0
    var classifyCount = 0
    let result = SharedCoreProxyTypeRouter.routeLazy(
      rawType: "Synthetic",
      nativeFallback: {
        fallbackCount += 1
        return self.unknown
      },
      classifyProxyType: { rawType in
        classifyCount += 1
        return try classifyProxyType(rawType)
      }
    )

    XCTAssertEqual(result.classification, unknown, file: file, line: line)
    XCTAssertEqual(result.source, .nativeFallback, file: file, line: line)
    XCTAssertEqual(result.status, expectedStatus, file: file, line: line)
    XCTAssertEqual(classifyCount, 1, file: file, line: line)
    XCTAssertEqual(fallbackCount, 1, file: file, line: line)
  }
}

private struct SyntheticLazyRouteError: Error {}
