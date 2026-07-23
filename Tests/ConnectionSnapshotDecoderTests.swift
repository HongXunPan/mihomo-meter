import Foundation
import XCTest

@testable import MihomoMeter

final class ConnectionSnapshotDecoderTests: XCTestCase {
  func testDecodesTextAndBinaryWebSocketMessages() throws {
    let data = try FixtureLoader.data(named: "connections-next")
    let text = try XCTUnwrap(String(data: data, encoding: .utf8))
    let decoder = ConnectionSnapshotDecoder()

    XCTAssertEqual(
      try decoder.decode(.data(data)).connections.count,
      2
    )
    XCTAssertEqual(
      try decoder.decode(.string(text)).downloadTotal,
      2_900
    )
  }

  func testRejectsUnsupportedSnapshot() {
    let decoder = ConnectionSnapshotDecoder()

    XCTAssertThrowsError(try decoder.decode(.string(#"{"unexpected":true}"#))) {
      error in
      XCTAssertEqual(error as? ConnectionStreamError, .unsupportedResponse)
    }
  }
}
