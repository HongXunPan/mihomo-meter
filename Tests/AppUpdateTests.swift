import Foundation
import XCTest

@testable import MihomoMeter

final class SemanticVersionTests: XCTestCase {
  func testParsesReleaseTagAndComparesComponents() throws {
    let current = try XCTUnwrap(SemanticVersion("1.2.9"))
    let nextPatch = try XCTUnwrap(SemanticVersion("v1.2.10"))
    let nextMinor = try XCTUnwrap(SemanticVersion("1.3.0"))

    XCTAssertLessThan(current, nextPatch)
    XCTAssertLessThan(nextPatch, nextMinor)
    XCTAssertEqual(nextMinor.description, "1.3.0")
  }

  func testRejectsNonReleaseVersionForms() {
    XCTAssertNil(SemanticVersion("1.2"))
    XCTAssertNil(SemanticVersion("1.2.3-beta.1"))
    XCTAssertNil(SemanticVersion("01.2.3"))
    XCTAssertNil(SemanticVersion("v1.2.3.4"))
  }
}

final class GitHubReleaseClientTests: XCTestCase {
  func testDecodesSyntheticLatestRelease() throws {
    let release = try GitHubReleaseClient.decodeRelease(
      from: Data(
        """
        {
          "tag_name": "v1.4.2",
          "html_url": "https://github.com/HongXunPan/mihomo-meter/releases/tag/v1.4.2"
        }
        """.utf8
      )
    )

    XCTAssertEqual(release.version, SemanticVersion("1.4.2"))
    XCTAssertEqual(
      release.pageURL.absoluteString,
      "https://github.com/HongXunPan/mihomo-meter/releases/tag/v1.4.2"
    )
  }

  func testRejectsNonGitHubReleaseURL() {
    XCTAssertThrowsError(
      try GitHubReleaseClient.decodeRelease(
        from: Data(
          """
          {
            "tag_name": "v1.4.2",
            "html_url": "https://example.com/releases/v1.4.2"
          }
          """.utf8
        )
      )
    ) { error in
      XCTAssertEqual(error as? GitHubReleaseClientError, .invalidReleaseURL)
    }
  }
}

@MainActor
final class AppUpdateModelTests: TrafficMonitorTestCase {
  func testReportsNewerRelease() async throws {
    let release = AppRelease(
      version: try XCTUnwrap(SemanticVersion("1.1.0")),
      pageURL: try XCTUnwrap(URL(string: "https://github.com/example/releases/v1.1.0"))
    )
    let model = AppUpdateModel(
      currentVersionString: "1.0.0",
      releaseClient: AppUpdateTestClient(release: release)
    )

    model.checkForUpdates()

    try await waitUntil {
      model.state == .updateAvailable(release)
    }
  }

  func testReportsCurrentVersionAsUpToDate() async throws {
    let release = AppRelease(
      version: try XCTUnwrap(SemanticVersion("1.0.0")),
      pageURL: try XCTUnwrap(URL(string: "https://github.com/example/releases/v1.0.0"))
    )
    let model = AppUpdateModel(
      currentVersionString: "1.0.0",
      releaseClient: AppUpdateTestClient(release: release)
    )

    model.checkForUpdates()

    try await waitUntil {
      model.state == .upToDate
    }
  }
}

private actor AppUpdateTestClient: LatestAppReleaseFetching {
  let release: AppRelease?

  init(release: AppRelease?) {
    self.release = release
  }

  func fetchLatestRelease() -> AppRelease? {
    release
  }
}
