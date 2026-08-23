import XCTest

@testable import MihomoMeter

@MainActor
final class AppHelpLinksTests: XCTestCase {
  func testMihomoGuidanceLinksRemainHighestPriority() {
    XCTAssertEqual(
      Array(AppHelpLink.allCases.prefix(3)),
      [.userGuide, .prepareMihomo, .subscriptionConfiguration]
    )
  }

  func testPrimaryHelpLinkTargetsProjectWiki() {
    XCTAssertEqual(AppHelpLink.userGuide.title, "Mihomo Meter 使用指南（Wiki）")
    XCTAssertEqual(AppHelpLink.userGuide.destination.host, "github.com")
    XCTAssertEqual(AppHelpLink.userGuide.destination.path, "/HongXunPan/mihomo-meter/wiki")
  }

  func testStatusMenuHelpStartsWithProjectWiki() {
    let controller = AppHelpMenuController()
    let firstItem = controller.menuItem.submenu?.items.first

    XCTAssertEqual(controller.menuItem.title, "帮助")
    XCTAssertEqual(firstItem?.title, AppHelpLink.userGuide.title)
    XCTAssertEqual(
      (firstItem?.representedObject as? NSURL).map { $0 as URL },
      AppHelpLink.userGuide.destination
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

  func testPrepareMihomoLinkUsesBeginnerFacingTitle() {
    XCTAssertEqual(AppHelpLink.prepareMihomo.title, "第一次使用：从零开始")
  }

  func testSubscriptionConfigurationLinkTargetsDedicatedWikiPage() {
    XCTAssertEqual(
      AppHelpLink.subscriptionConfiguration.destination.path,
      "/HongXunPan/mihomo-meter/wiki/配置订阅地址"
    )
  }
}
