import XCTest

@testable import MihomoMeter

final class AppHelpLinksTests: XCTestCase {
  func testMihomoGuidanceLinksRemainHighestPriority() {
    XCTAssertEqual(
      Array(AppHelpLink.allCases.prefix(2)),
      [.prepareMihomo, .mihomoControllerConfiguration]
    )
  }

  func testAllLinksUseTrustedHTTPSDestinations() {
    let destinations = AppHelpLink.allCases.map(\.destination)

    XCTAssertTrue(destinations.allSatisfy { $0.scheme == "https" })
    XCTAssertEqual(
      Set(destinations.compactMap(\.host)),
      ["github.com", "wiki.metacubex.one"]
    )
  }

  func testPrepareMihomoLinkTargetsDedicatedWikiPage() {
    XCTAssertEqual(
      AppHelpLink.prepareMihomo.destination.path,
      "/HongXunPan/mihomo-meter/wiki/准备-Mihomo"
    )
  }
}
