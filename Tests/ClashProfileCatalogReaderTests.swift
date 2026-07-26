import Foundation
import XCTest

@testable import MihomoMeter

final class ClashProfileCatalogReaderTests: XCTestCase {
  func testReadsOnlyRemoteProfilesAndIgnoresUnknownFields() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try write(
      """
      current: remote-a
      items:
        - uid: remote-a
          type: remote
          name: 主订阅
          url: https://EXAMPLE.com/sub?token=secret
          extra:
            upload: 100
        - uid: local-a
          type: local
          name: 本地配置
        - uid: incomplete
          type: remote
          name: 不完整订阅
      """,
      to: directory
    )

    let catalog = try YAMLClashProfileCatalogReader().readCatalog(in: directory)

    XCTAssertEqual(catalog.currentUID, "remote-a")
    XCTAssertEqual(catalog.profiles.count, 1)
    XCTAssertEqual(catalog.currentProfile?.name, "主订阅")
    XCTAssertEqual(catalog.profiles.first?.subscriptionDomain, "example.com")
    XCTAssertEqual(catalog.ignoredRemoteProfileCount, 1)
  }

  func testRejectsDuplicateRemoteUID() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try write(
      """
      items:
        - uid: duplicate
          type: remote
          name: 订阅一
          url: https://one.example/sub
        - uid: duplicate
          type: remote
          name: 订阅二
          url: https://two.example/sub
      """,
      to: directory
    )

    XCTAssertThrowsError(try YAMLClashProfileCatalogReader().readCatalog(in: directory)) {
      XCTAssertEqual($0 as? ClashProfileCatalogReaderError, .duplicateUID)
    }
  }

  func testKeepsHTTPProfileVisibleButMarksItUnsupportedForQuery() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try write(
      """
      items:
        - uid: legacy
          type: remote
          name: 旧订阅
          url: http://legacy.example/sub
      """,
      to: directory
    )

    let profile = try XCTUnwrap(
      YAMLClashProfileCatalogReader().readCatalog(in: directory).profiles.first
    )

    XCTAssertFalse(profile.supportsActiveQuery)
  }

  private func temporaryDirectory() -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("MihomoMeterProfileReaderTests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory
  }

  private func write(_ contents: String, to directory: URL) throws {
    try contents.write(
      to: directory.appendingPathComponent("profiles.yaml"),
      atomically: true,
      encoding: .utf8
    )
  }
}
