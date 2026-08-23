import Foundation
import Security
import XCTest

@testable import MihomoMeter

final class DiagnosticExportReportTests: XCTestCase {
  func testExportUsesWhitelistWithoutIdentifiersOrRawLogContent() throws {
    let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
    let requestID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let subscriptionID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let keychainContext = KeychainDiagnosticContext(
      requestID: requestID,
      operation: .load,
      reason: .applicationStartup
    )
    let profileContext = ProfileQuotaDiagnosticContext(
      requestID: requestID,
      subscriptionID: subscriptionID,
      urlFingerprint: "abcdef0123456789abcdef0123456789",
      trigger: .manual,
      isCurrentProfile: true,
      proxyKind: .mixed,
      userAgentSource: .mihomoConfiguration
    )
    let events = [
      AppDiagnosticEvent.applicationLaunched(
        AppCodeSigningSummary(
          identifier: "com.example.private-build",
          teamIdentifier: "PRIVATE-TEAM",
          isAdHoc: true,
          inspectionStatus: errSecSuccess
        )
      ).diagnosticExportEvent(at: timestamp),
      AppDiagnosticEvent.keychainOperationStarted(keychainContext)
        .diagnosticExportEvent(at: timestamp),
      AppDiagnosticEvent.profileQuotaQueryFinished(
        profileContext,
        outcome: .missingSubscriptionInfo(statusCode: 200),
        elapsedMilliseconds: 12,
        retryAfterSeconds: 300
      ).diagnosticExportEvent(at: timestamp),
    ]
    let report = DiagnosticExportReport(
      generatedAt: timestamp,
      application: DiagnosticExportEnvironment(
        platform: "macOS",
        version: "1.2.3",
        build: "456",
        operatingSystem: "macOS 15.0",
        architecture: "arm64"
      ),
      connectionState: "connected",
      events: events
    )

    let contents = String(decoding: try report.encodedData(), as: UTF8.self)

    XCTAssertTrue(contents.contains("\"schemaVersion\" : 1"))
    XCTAssertTrue(contents.contains("\"connectionState\" : \"connected\""))
    XCTAssertTrue(contents.contains("\"category\" : \"profile_quota.query.finished\""))
    XCTAssertTrue(contents.contains("\"httpStatus\" : 200"))
    XCTAssertFalse(contents.contains(requestID.uuidString.lowercased()))
    XCTAssertFalse(contents.contains(subscriptionID.uuidString.lowercased()))
    XCTAssertFalse(contents.contains("abcdef012345"))
    XCTAssertFalse(contents.contains("com.example.private-build"))
    XCTAssertFalse(contents.contains("PRIVATE-TEAM"))
    XCTAssertFalse(contents.contains("request_id"))
    XCTAssertFalse(contents.contains("subscription_id"))
    XCTAssertFalse(contents.contains("url_fingerprint"))
  }

  func testLoggerRetainsOnlyLatestExportEvents() async {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("MihomoMeter-DiagnosticExportTests-\(UUID().uuidString)")
    defer {
      try? FileManager.default.removeItem(at: directoryURL)
    }
    let logger = AppDiagnosticLogger(
      directoryURL: directoryURL,
      maxFileSizeBytes: 1_024,
      maximumExportEventCount: 3
    )

    for attempt in 1...5 {
      await logger.record(
        .connectionAttemptStarted(trigger: .automaticRetry, attemptNumber: attempt)
      )
    }

    let events = await logger.diagnosticExportSnapshot()
    XCTAssertEqual(events.count, 3)
    XCTAssertEqual(events.map(\.attemptNumber), [3, 4, 5])
  }
}
