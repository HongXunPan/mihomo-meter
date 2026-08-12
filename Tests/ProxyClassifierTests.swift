import XCTest

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
}
