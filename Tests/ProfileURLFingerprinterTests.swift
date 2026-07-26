import Foundation
import XCTest

@testable import MihomoMeter

final class ProfileURLFingerprinterTests: XCTestCase {
  func testNormalizesSchemeHostDefaultPortAndFragment() throws {
    let first = try XCTUnwrap(URL(string: "HTTPS://EXAMPLE.com:443/sub?token=x#fragment"))
    let second = try XCTUnwrap(URL(string: "https://example.com/sub?token=x"))

    XCTAssertEqual(
      try ProfileURLNormalizer.normalizedString(from: first),
      try ProfileURLNormalizer.normalizedString(from: second)
    )
  }

  func testProducesStableHMACWithoutExposingRawURL() async throws {
    let fingerprinter = HMACProfileURLFingerprinter(
      keyStore: TestProfileFingerprintKeyStore()
    )
    let url = try XCTUnwrap(URL(string: "https://example.com/sub?token=private"))

    let first = try await fingerprinter.fingerprint(for: url)
    let second = try await fingerprinter.fingerprint(for: url)

    XCTAssertEqual(first, second)
    XCTAssertEqual(first.count, 64)
    XCTAssertFalse(first.contains("private"))
    XCTAssertFalse(first.contains("example.com"))
  }
}
