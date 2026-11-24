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

    let binary = try decoder.decodeWithPayloadSize(.data(data))
    let textual = try decoder.decodeWithPayloadSize(.string(text))
    XCTAssertEqual(binary.snapshot.connections.count, 2)
    XCTAssertEqual(textual.snapshot.downloadTotal, 2_900)
    XCTAssertEqual(binary.payloadByteCount, data.count)
    XCTAssertEqual(textual.payloadByteCount, data.count)
  }

  func testRejectsUnsupportedSnapshot() {
    let decoder = ConnectionSnapshotDecoder()

    XCTAssertThrowsError(try decoder.decode(.string(#"{"unexpected":true}"#))) {
      error in
      XCTAssertEqual(error as? ConnectionStreamError, .unsupportedResponse)
    }
  }

  func testDecodesSyntheticConnectionStartFormats() throws {
    let values = [
      "2026-07-30T08:00:00Z",
      "2026-07-30T08:00:00.123Z",
      "2026-07-30T08:00:00.123456Z",
      "2026-07-30T16:00:00+08:00",
    ]

    for value in values {
      let payload = Data(
        """
        {"downloadTotal":0,"uploadTotal":0,"connections":[{
          "id":"synthetic","upload":0,"download":0,"chains":[],"start":"\(value)"
        }]}
        """.utf8
      )
      let snapshot = try ConnectionSnapshotDecoder().decode(.data(payload))
      let actual = try XCTUnwrap(snapshot.connections.first?.startedAt, value)
      let formatter = ISO8601DateFormatter()
      if value.contains(".") {
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      } else {
        formatter.formatOptions = [.withInternetDateTime]
      }
      let expected = try XCTUnwrap(formatter.date(from: value), value)
      XCTAssertLessThan(abs(actual.timeIntervalSince(expected)), 0.01, value)
    }
  }

  func testKeepsInvalidConnectionStartOptional() throws {
    let payload = Data(
      """
      {"downloadTotal":0,"uploadTotal":0,"connections":[{
        "id":"synthetic","upload":0,"download":0,"chains":[],"start":"invalid"
      }]}
      """.utf8
    )

    let snapshot = try ConnectionSnapshotDecoder().decode(.data(payload))
    XCTAssertNil(snapshot.connections.first?.startedAt)
  }
}
