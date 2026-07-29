import Foundation
import XCTest

@testable import MihomoMeter

final class MihomoProxyProviderModelsTests: XCTestCase {
  func testDecodesCurrentUppercaseSubscriptionInfo() throws {
    let response = try decode(
      """
      {
        "providers": {
          "provider-a": {
            "updatedAt": "2026-07-26T02:03:04.123Z",
            "subscriptionInfo": {
              "Upload": 100,
              "Download": 250,
              "Total": 1000,
              "Expire": 1800000000
            }
          }
        }
      }
      """
    )

    guard case .single(let candidate) = response.runtimeQuotaSelection else {
      return XCTFail("应识别唯一有效配额候选")
    }
    XCTAssertEqual(candidate.sourceKey, "provider-a")
    XCTAssertEqual(candidate.traffic.usedBytes, 350)
    XCTAssertEqual(candidate.traffic.remainingBytes, 650)
    XCTAssertEqual(
      candidate.sourceUpdatedAt,
      Date(timeIntervalSince1970: 1_785_031_384.123)
    )
    XCTAssertEqual(candidate.expireAt, Date(timeIntervalSince1970: 1_800_000_000))
  }

  func testAcceptsLowercaseFieldsAndRejectsInvalidCandidates() throws {
    let response = try decode(
      """
      {
        "providers": {
          "lowercase": {
            "subscriptionInfo": {
              "upload": 1,
              "download": 2,
              "total": 10,
              "expire": 0
            }
          },
          "missing-total": {
            "subscriptionInfo": {"Upload": 1, "Download": 2}
          },
          "negative": {
            "subscriptionInfo": {"Upload": -1, "Download": 2, "Total": 10}
          },
          "zero-total": {
            "subscriptionInfo": {"Upload": 1, "Download": 2, "Total": 0}
          }
        }
      }
      """
    )

    guard case .single(let candidate) = response.runtimeQuotaSelection else {
      return XCTFail("无效 Provider 不应进入候选计数")
    }
    XCTAssertEqual(candidate.sourceKey, "lowercase")
    XCTAssertEqual(candidate.traffic.remainingBytes, 7)
    XCTAssertNil(candidate.expireAt)
  }

  func testReportsMultipleValidCandidatesWithoutAggregating() throws {
    let response = try decode(
      """
      {
        "providers": {
          "provider-a": {
            "subscriptionInfo": {"Upload": 1, "Download": 2, "Total": 10}
          },
          "provider-b": {
            "subscriptionInfo": {"Upload": 3, "Download": 4, "Total": 20}
          }
        }
      }
      """
    )

    XCTAssertEqual(response.runtimeQuotaSelection, .multiple(count: 2))
  }

  private func decode(_ json: String) throws -> MihomoProxyProvidersResponse {
    try JSONDecoder().decode(
      MihomoProxyProvidersResponse.self,
      from: Data(json.utf8)
    )
  }
}
