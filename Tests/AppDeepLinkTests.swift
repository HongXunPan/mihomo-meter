import Foundation
import XCTest

@testable import MihomoMeter

final class AppDeepLinkTests: XCTestCase {
  func testAcceptsOnlyFixedDeepLinks() throws {
    XCTAssertEqual(
      AppDeepLink.target(for: try XCTUnwrap(URL(string: AppDeepLink.statisticsURL))),
      .statistics
    )
    XCTAssertEqual(
      AppDeepLink.target(for: try XCTUnwrap(URL(string: AppDeepLink.subscriptionQuotaURL))),
      .subscriptionQuota
    )
    XCTAssertEqual(
      AppDeepLink.target(for: try XCTUnwrap(URL(string: AppDeepLink.connectionSettingsURL))),
      .controllerSettings
    )
  }

  func testRejectsParametersAndUnknownTargets() throws {
    XCTAssertEqual(AppDeepLink.fallbackTarget, .mainWindow)

    let rejectedValues = [
      "mihomo-meter://statistics/",
      "mihomo-meter://statistics?range=day",
      "mihomo-meter://statistics#detail",
      "mihomo-meter://unknown",
      "https://example.com",
    ]

    for value in rejectedValues {
      XCTAssertNil(
        AppDeepLink.target(for: try XCTUnwrap(URL(string: value))),
        value
      )
    }
  }
}
