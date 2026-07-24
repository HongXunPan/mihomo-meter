import Foundation
import Security
import XCTest

@testable import MihomoMeter

final class DiagnosticLoggerTests: XCTestCase {
  func testWritesOnlyTypedDiagnosticFields() async throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer {
      try? FileManager.default.removeItem(at: directoryURL)
    }

    let logger = DebugDiagnosticLogger(
      directoryURL: directoryURL,
      maxFileSizeBytes: 4_096
    )
    let keychainContext = KeychainDiagnosticContext(
      requestID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      operation: .load,
      reason: .applicationStartup
    )

    await logger.record(
      .applicationLaunched(
        AppCodeSigningSummary(
          identifier: "com.example.MihomoMeter",
          teamIdentifier: nil,
          isAdHoc: true,
          inspectionStatus: errSecSuccess
        )
      )
    )
    await logger.record(.keychainOperationStarted(keychainContext))
    await logger.record(
      .keychainOperationFinished(
        keychainContext,
        outcome: .failed(errSecAuthFailed),
        elapsedMilliseconds: 12
      )
    )
    await logger.record(
      .connectionAttemptStarted(
        trigger: .immediateRetry,
        attemptNumber: 2
      )
    )
    await logger.record(
      .connectionReconnectScheduled(
        reason: .streamNetwork(.networkConnectionLost),
        delaySeconds: 4
      )
    )

    let contents = try String(
      contentsOf: directoryURL.appendingPathComponent("diagnostics.log"),
      encoding: .utf8
    )

    XCTAssertTrue(contents.contains("event=application.launched"))
    XCTAssertTrue(contents.contains("signing=adhoc"))
    XCTAssertTrue(contents.contains("team_id=none"))
    XCTAssertTrue(contents.contains("operation=load"))
    XCTAssertTrue(contents.contains("reason=application_startup"))
    XCTAssertTrue(contents.contains("request_id=00000000-0000-0000-0000-000000000001"))
    XCTAssertTrue(contents.contains("status=\(errSecAuthFailed)"))
    XCTAssertTrue(contents.contains("trigger=immediate_retry"))
    XCTAssertTrue(contents.contains("reason=stream_network"))
    XCTAssertTrue(contents.contains("delay_seconds=4"))
    XCTAssertFalse(contents.contains(NSHomeDirectory()))
    XCTAssertFalse(contents.contains("synthetic-secret"))
  }

  func testRotatesLogBeforeExceedingSizeBudget() async throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer {
      try? FileManager.default.removeItem(at: directoryURL)
    }

    let sizeBudget: UInt64 = 320
    let logger = DebugDiagnosticLogger(
      directoryURL: directoryURL,
      maxFileSizeBytes: sizeBudget
    )
    let context = KeychainDiagnosticContext(
      operation: .load,
      reason: .applicationStartup
    )

    for _ in 0..<12 {
      await logger.record(.keychainOperationStarted(context))
    }

    let currentURL = directoryURL.appendingPathComponent("diagnostics.log")
    let archivedURL = directoryURL.appendingPathComponent("diagnostics.previous.log")
    XCTAssertTrue(FileManager.default.fileExists(atPath: currentURL.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: archivedURL.path))
    XCTAssertLessThanOrEqual(try fileSize(at: currentURL), sizeBudget)
    XCTAssertLessThanOrEqual(try fileSize(at: archivedURL), sizeBudget)
  }

  func testRemovesExpiredLogsBeforeWritingNewEvent() async throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer {
      try? FileManager.default.removeItem(at: directoryURL)
    }
    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )

    let currentURL = directoryURL.appendingPathComponent("diagnostics.log")
    let archivedURL = directoryURL.appendingPathComponent("diagnostics.previous.log")
    try Data("expired-current".utf8).write(to: currentURL)
    try Data("expired-archive".utf8).write(to: archivedURL)
    let expiredDate = Date(timeIntervalSinceNow: -(8 * 24 * 60 * 60))
    try FileManager.default.setAttributes(
      [.modificationDate: expiredDate],
      ofItemAtPath: currentURL.path
    )
    try FileManager.default.setAttributes(
      [.modificationDate: expiredDate],
      ofItemAtPath: archivedURL.path
    )

    let logger = DebugDiagnosticLogger(directoryURL: directoryURL)
    await logger.record(
      .connectionAttemptStarted(
        trigger: .applicationStartup,
        attemptNumber: 1
      )
    )

    let contents = try String(contentsOf: currentURL, encoding: .utf8)
    XCTAssertFalse(contents.contains("expired-current"))
    XCTAssertTrue(contents.contains("event=connection.attempt.started"))
    XCTAssertFalse(FileManager.default.fileExists(atPath: archivedURL.path))
  }

  func testClassifiesReconnectReasonsWithoutRawErrorText() {
    XCTAssertEqual(
      ConnectionDiagnosticReason.classify(
        ConnectionStreamError.network(.networkConnectionLost)
      ),
      .streamNetwork(.networkConnectionLost)
    )
    XCTAssertEqual(
      ConnectionDiagnosticReason.classify(
        ConnectionStreamError.network(.cancelled),
        dataWasStale: true
      ),
      .dataStale
    )
    XCTAssertEqual(
      ConnectionDiagnosticReason.classify(
        MihomoControllerError.authenticationFailed
      ),
      .authenticationFailed
    )
  }

  private func makeTemporaryDirectoryURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("MihomoMeter-DiagnosticLoggerTests-\(UUID().uuidString)")
  }

  private func fileSize(at url: URL) throws -> UInt64 {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes[.size] as? NSNumber)?.uint64Value ?? 0
  }
}
