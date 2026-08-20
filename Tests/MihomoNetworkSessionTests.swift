import Foundation
import XCTest

@testable import MihomoMeter

final class MihomoNetworkSessionTests: XCTestCase {
  func testSharedSessionDisablesURLCache() {
    let configuration = MihomoNetworkSession.shared.configuration

    XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
    XCTAssertNil(configuration.urlCache)
  }
}
