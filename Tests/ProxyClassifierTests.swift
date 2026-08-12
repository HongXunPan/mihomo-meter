import XCTest
import os

@testable import MihomoMeter

final class ProxyClassifierTests: XCTestCase {
  private let classifier = ProxyClassifier(
    catalog: ProxyCatalog(
      typesByName: [
        "DIRECT": "Direct",
        "REJECT": "Reject",
        "REJECT-DROP": "RejectDrop",
        "Synthetic Group": "Selector",
        "Synthetic Proxy": "Vmess",
      ]
    )
  )

  func testClassifiesConcreteLeafWithoutUsingOuterGroup() {
    XCTAssertEqual(
      classifier.classify(chains: ["Synthetic Proxy", "Synthetic Group"]),
      ProxyClassification(category: .proxy, unknownReason: nil)
    )
  }

  func testClassifiesEverySupportedConcreteProxyType() {
    let supportedTypes = [
      "AnyTLS",
      "Http",
      "Hysteria",
      "Hysteria2",
      "Shadowsocks",
      "ShadowsocksR",
      "Snell",
      "Socks5",
      "Ssh",
      "Trojan",
      "Tuic",
      "Vless",
      "Vmess",
      "WireGuard",
    ]

    for type in supportedTypes {
      let classifier = ProxyClassifier(
        catalog: ProxyCatalog(typesByName: ["Synthetic Proxy": type])
      )
      XCTAssertEqual(
        classifier.classify(chains: ["Synthetic Proxy"]),
        ProxyClassification(category: .proxy, unknownReason: nil),
        "\(type) 应归类为 Proxy"
      )
    }
  }

  func testKeepsDirectAndRejectSeparateFromProxy() {
    XCTAssertEqual(
      classifier.classify(chains: ["DIRECT"]).category,
      .direct
    )
    XCTAssertEqual(
      classifier.classify(chains: ["REJECT"]).category,
      .reject
    )
    XCTAssertEqual(
      classifier.classify(chains: ["REJECT-DROP"]).category,
      .reject
    )
  }

  func testDoesNotGuessMissingOrAmbiguousLeaf() {
    XCTAssertEqual(
      classifier.classify(chains: []).unknownReason,
      .emptyChain
    )
    XCTAssertEqual(
      classifier.classify(chains: ["Not In Catalog"]).unknownReason,
      .missingCatalogEntry
    )
    XCTAssertEqual(
      classifier.classify(chains: ["Synthetic Group"]).unknownReason,
      .ambiguousProxyType
    )
  }

  func testInvokesInjectedResolverOnlyAfterCatalogHitWithNativeClassification() {
    let invocations = OSAllocatedUnfairLock(
      initialState: [(rawType: String, classification: ProxyClassification)]()
    )
    let classifier = ProxyClassifier(
      catalog: ProxyCatalog(typesByName: ["Synthetic Proxy": "Vmess"]),
      resolveProxyType: { rawType, nativeClassification in
        invocations.withLock {
          $0.append((rawType: rawType, classification: nativeClassification))
        }
        return nativeClassification
      }
    )

    _ = classifier.classify(chains: [])
    _ = classifier.classify(chains: ["Missing"])
    XCTAssertEqual(
      classifier.classify(chains: ["Synthetic Proxy"]),
      ProxyClassification(category: .proxy, unknownReason: nil)
    )
    XCTAssertEqual(invocations.withLock { $0.count }, 1)
    XCTAssertEqual(invocations.withLock { $0.first?.rawType }, "Vmess")
    XCTAssertEqual(
      invocations.withLock { $0.first?.classification },
      ProxyClassification(category: .proxy, unknownReason: nil)
    )
  }

  func testLazyResolverControlsWhetherNativeClassificationIsEvaluated() {
    let invocations = OSAllocatedUnfairLock(initialState: [String]())
    let sharedClassifier = ProxyClassifier(
      catalog: ProxyCatalog(typesByName: ["Synthetic": "Selector"]),
      resolveProxyTypeLazily: { rawType, _ in
        invocations.withLock { $0.append(rawType) }
        return ProxyClassification(category: .proxy, unknownReason: nil)
      }
    )
    XCTAssertEqual(
      sharedClassifier.classify(chains: ["Synthetic"]),
      ProxyClassification(category: .proxy, unknownReason: nil)
    )

    let fallbackClassifier = ProxyClassifier(
      catalog: ProxyCatalog(typesByName: ["Synthetic": "Selector"]),
      resolveProxyTypeLazily: { _, nativeFallback in nativeFallback() }
    )
    XCTAssertEqual(
      fallbackClassifier.classify(chains: ["Synthetic"]),
      ProxyClassification(category: .unknown, unknownReason: .ambiguousProxyType)
    )
    XCTAssertEqual(invocations.withLock { $0 }, ["Selector"])
  }
}
