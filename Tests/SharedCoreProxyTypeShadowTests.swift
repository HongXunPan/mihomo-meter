import XCTest
import os

@testable import MihomoMeter

final class SharedCoreProxyTypeShadowTests: XCTestCase {
  private let proxy = ProxyClassification(category: .proxy, unknownReason: nil)
  private let direct = ProxyClassification(category: .direct, unknownReason: nil)
  private let reject = ProxyClassification(category: .reject, unknownReason: nil)
  private let unknown = ProxyClassification(
    category: .unknown,
    unknownReason: .ambiguousProxyType
  )

  func testRouterMatchesEveryStableSharedClassificationWithoutChangingNativeResult() {
    let cases: [(String, ProxyClassification, SharedProxyTypeClassification)] = [
      ("Vmess", proxy, .proxy),
      ("Direct", direct, .direct),
      ("Reject", reject, .reject),
    ]

    for (rawType, nativeClassification, sharedClassification) in cases {
      let result = SharedCoreProxyTypeRouter.route(
        rawType: rawType,
        nativeClassification: nativeClassification,
        classifyProxyType: { _ in sharedClassification }
      )

      XCTAssertEqual(result.classification, nativeClassification)
      XCTAssertEqual(result.source, .sharedShadow)
      XCTAssertEqual(result.status, .matched)
    }
  }

  func testRouterKeepsNativeResultForUnrecognizedMismatchAndAdapterFailures() {
    let unrecognized = route(sharedResult: .unrecognized, nativeClassification: unknown)
    let mismatch = route(sharedResult: .direct, nativeClassification: proxy)
    let failures: [(SharedProxyTypeAdapterError, SharedCoreProxyTypeRouteStatus)] = [
      (.unsupportedABIVersion(2), .abiMismatch),
      (.nativeCallFailed(-1), .nativeCallFailed),
      (.unsupportedProxyTypeInput, .unsupportedInput),
      (.proxyTypeInputTooLong, .inputTooLong),
      (.unsupportedProxyTypeCategory(99), .unexpectedResult),
    ]

    XCTAssertEqual(unrecognized.classification, unknown)
    XCTAssertEqual(unrecognized.source, .nativeFallback)
    XCTAssertEqual(unrecognized.status, .unrecognized)
    XCTAssertEqual(mismatch.classification, proxy)
    XCTAssertEqual(mismatch.source, .nativeFallback)
    XCTAssertEqual(mismatch.status, .mismatch)

    for (error, expectedStatus) in failures {
      let result = SharedCoreProxyTypeRouter.route(
        rawType: "Synthetic",
        nativeClassification: proxy,
        classifyProxyType: { _ in throw error }
      )
      XCTAssertEqual(result.classification, proxy)
      XCTAssertEqual(result.source, .nativeFallback)
      XCTAssertEqual(result.status, expectedStatus)
    }

    let unknownFailure = SharedCoreProxyTypeRouter.route(
      rawType: "Synthetic",
      nativeClassification: proxy,
      classifyProxyType: { _ in throw SyntheticError() }
    )
    XCTAssertEqual(unknownFailure.classification, proxy)
    XCTAssertEqual(unknownFailure.source, .nativeFallback)
    XCTAssertEqual(unknownFailure.status, .unknownFailure)
  }

  func testShadowDeduplicatesSourceAndStatusAndIgnoresReporterFailure() {
    let observations = OSAllocatedUnfairLock(
      initialState: [SharedCoreProxyTypeShadowObservation]()
    )
    SharedCoreProxyTypeShadow.configure { observation in
      observations.withLock { $0.append(observation) }
      throw SyntheticError()
    }
    defer {
      SharedCoreProxyTypeShadow.configure(reporter: nil)
    }

    for _ in 0..<2 {
      XCTAssertEqual(
        SharedCoreProxyTypeShadow.observe(
          rawType: "Vmess",
          nativeClassification: proxy,
          classifyProxyType: { _ in .proxy }
        ),
        proxy
      )
    }
    XCTAssertEqual(
      SharedCoreProxyTypeShadow.observe(
        rawType: "Selector",
        nativeClassification: unknown,
        classifyProxyType: { _ in .unrecognized }
      ),
      unknown
    )

    XCTAssertEqual(
      observations.withLock { $0 },
      [
        SharedCoreProxyTypeShadowObservation(source: .sharedShadow, status: .matched),
        SharedCoreProxyTypeShadowObservation(source: .nativeFallback, status: .unrecognized),
      ]
    )
  }

  func testObservationGateKeysBySourceAndStatus() {
    var gate = SharedCoreProxyTypeShadowObservationGate()
    let matched = SharedCoreProxyTypeShadowObservation(
      source: .sharedShadow,
      status: .matched
    )
    let fallback = SharedCoreProxyTypeShadowObservation(
      source: .nativeFallback,
      status: .matched
    )

    XCTAssertTrue(gate.shouldReport(matched))
    XCTAssertFalse(gate.shouldReport(matched))
    XCTAssertTrue(gate.shouldReport(fallback))
    gate.reset()
    XCTAssertTrue(gate.shouldReport(matched))
  }

  private func route(
    sharedResult: SharedProxyTypeClassification,
    nativeClassification: ProxyClassification
  ) -> SharedCoreProxyTypeRouteResult {
    SharedCoreProxyTypeRouter.route(
      rawType: "Synthetic",
      nativeClassification: nativeClassification,
      classifyProxyType: { _ in sharedResult }
    )
  }

  private struct SyntheticError: Error {}
}
