import Foundation
import XCTest

@testable import MihomoMeter

final class ProcessPerformanceDiagnosticsTests: XCTestCase {
  func testComputesIntervalCpuAndCurrentResidentMemory() {
    let previous = ProcessPerformanceSnapshot(
      uptimeSeconds: 100,
      cpuSeconds: 5,
      residentBytes: 32 * 1_024 * 1_024
    )
    let current = ProcessPerformanceSnapshot(
      uptimeSeconds: 110,
      cpuSeconds: 8.6,
      residentBytes: 128 * 1_024 * 1_024
    )

    let sample = ProcessPerformanceDiagnostics.sample(
      from: previous,
      to: current,
      displayMode: .directDraw,
      connectionDecode: ConnectionDecodeIntervalMetrics(
        snapshotCount: 2,
        minimumConnectionCount: 3,
        maximumConnectionCount: 8,
        totalDecodeMilliseconds: 4,
        totalPayloadBytes: 2_800,
        totalConnectionEntries: 11,
        maximumDecodeMilliseconds: 2
      )
    )

    XCTAssertEqual(sample?.cpuPercentTenths, 360)
    XCTAssertEqual(sample?.residentMiB, 128)
    XCTAssertEqual(
      sample?.logMessage,
      "event=performance.sample display_mode=direct_draw date_parser_mode=format_style "
        + "cpu_percent_tenths=360 rss_mib=128 "
        + "connection_snapshots=2 connection_count_range=3-8 connection_decode_ms=4 "
        + "snapshot_bytes_total=2800 connection_entries_total=11 connection_decode_max_ms=2"
    )
  }

  func testRejectsInvalidIntervalsAndKeepsMemoryFailureExplicit() {
    let previous = ProcessPerformanceSnapshot(
      uptimeSeconds: 100,
      cpuSeconds: 10,
      residentBytes: nil
    )
    let invalid = ProcessPerformanceSnapshot(
      uptimeSeconds: 100,
      cpuSeconds: 11,
      residentBytes: nil
    )
    XCTAssertNil(
      ProcessPerformanceDiagnostics.sample(
        from: previous,
        to: invalid,
        displayMode: .directDraw,
        connectionDecode: .empty
      )
    )

    let valid = ProcessPerformanceSnapshot(
      uptimeSeconds: 110,
      cpuSeconds: 12,
      residentBytes: nil
    )
    let sample = ProcessPerformanceDiagnostics.sample(
      from: previous,
      to: valid,
      displayMode: .directDraw,
      connectionDecode: .empty
    )
    XCTAssertEqual(sample?.cpuPercentTenths, 200)
    XCTAssertNil(sample?.residentMiB)
    XCTAssertTrue(sample?.logMessage.contains("rss_mib=unknown") == true)
    XCTAssertTrue(sample?.logMessage.contains("connection_count_range=unknown") == true)
  }

  func testConnectionDecodeMetricsDrainAndReset() async {
    let recorder = ConnectionDecodePerformanceRecorder()
    await recorder.record(
      connectionCount: 8,
      payloadByteCount: 2_000,
      elapsedNanoseconds: 2_750_000
    )
    await recorder.record(
      connectionCount: 3,
      payloadByteCount: 800,
      elapsedNanoseconds: 1_250_000
    )

    let metrics = await recorder.drain()
    XCTAssertEqual(metrics.snapshotCount, 2)
    XCTAssertEqual(metrics.minimumConnectionCount, 3)
    XCTAssertEqual(metrics.maximumConnectionCount, 8)
    XCTAssertEqual(metrics.totalDecodeMilliseconds, 4)
    XCTAssertEqual(metrics.totalPayloadBytes, 2_800)
    XCTAssertEqual(metrics.totalConnectionEntries, 11)
    XCTAssertEqual(metrics.maximumDecodeMilliseconds, 2)
    let emptyMetrics = await recorder.drain()
    XCTAssertEqual(emptyMetrics, .empty)
  }

  func testPerformanceSampleIsLoggedButNotIncludedInDiagnosticExport() async throws {
    let projectURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let directoryURL = projectURL.appendingPathComponent(
      ".build/ProcessPerformanceDiagnosticsTests-\(UUID().uuidString)"
    )
    defer {
      try? FileManager.default.removeItem(at: directoryURL)
    }
    let logger = AppDiagnosticLogger(directoryURL: directoryURL)
    let sample = ProcessPerformanceSample(
      displayMode: .directDraw,
      cpuPercentTenths: 360,
      residentMiB: 128,
      connectionDecode: .empty
    )

    await logger.recordPerformance(sample)

    let contents = try String(contentsOf: logger.logFileURL, encoding: .utf8)
    XCTAssertTrue(contents.contains(sample.logMessage))
    let exportEvents = await logger.diagnosticExportSnapshot()
    XCTAssertTrue(exportEvents.isEmpty)
  }

  func testSamplingLimitsRemainBounded() {
    XCTAssertEqual(ProcessPerformanceDiagnostics.intervalSeconds, 60)
    XCTAssertEqual(ProcessPerformanceDiagnostics.maximumSampleCount, 720)
    XCTAssertEqual(
      ProcessPerformanceDiagnostics.intervalSeconds
        * ProcessPerformanceDiagnostics.maximumSampleCount,
      12 * 60 * 60
    )
  }

  func testSamplingIsDisabledWithoutExplicitEnvironmentFlag() {
    let task = ProcessPerformanceDiagnostics.startIfEnabled(
      variables: [:],
      logger: AppDiagnosticLogger.shared
    )
    XCTAssertNil(task)
  }
}
