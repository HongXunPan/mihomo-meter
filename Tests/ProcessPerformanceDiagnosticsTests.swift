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
      ),
      liveConnectionTable: LiveConnectionTableIntervalMetrics(
        isMountedAtEnd: true,
        mountCount: 1,
        unmountCount: 0,
        updateCount: 3,
        skippedUpdateCount: 1,
        fullReloadCount: 2,
        incrementalBatchCount: 1,
        rowMoveCount: 3,
        rowInsertionCount: 2,
        rowRemovalCount: 1,
        cellConfigurationCount: 12,
        visibleCellUpdateCount: 8,
        minimumRowCount: 3,
        maximumRowCount: 8,
        totalUpdateMilliseconds: 6,
        maximumUpdateMilliseconds: 4
      ),
      liveTableFreezePhase: .frozen
    )

    XCTAssertEqual(sample?.cpuPercentTenths, 360)
    XCTAssertEqual(sample?.residentMiB, 128)
    XCTAssertEqual(
      sample?.logMessage,
      "event=performance.sample display_mode=direct_draw date_parser_mode=format_style "
        + "cpu_percent_tenths=360 rss_mib=128 "
        + "connection_snapshots=2 connection_count_range=3-8 connection_decode_ms=4 "
        + "snapshot_bytes_total=2800 connection_entries_total=11 connection_decode_max_ms=2 "
        + "live_table_mounted=1 live_table_mounts=1 live_table_unmounts=0 "
        + "live_table_rows_range=3-8 live_table_updates=3 live_table_skipped_updates=1 "
        + "live_table_reloads=2 live_table_incremental_batches=1 "
        + "live_table_row_moves=3 live_table_row_insertions=2 live_table_row_removals=1 "
        + "live_table_cells=12 live_table_visible_cell_updates=8 "
        + "live_table_update_ms=6 live_table_update_max_ms=4 live_table_freeze_phase=frozen"
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
        connectionDecode: .empty,
        liveConnectionTable: .empty,
        liveTableFreezePhase: .disabled
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
      connectionDecode: .empty,
      liveConnectionTable: .empty,
      liveTableFreezePhase: .disabled
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

  @MainActor
  func testLiveConnectionTableMetricsDrainAndKeepMountState() {
    let recorder = LiveConnectionTablePerformanceRecorder()
    recorder.recordMount()
    recorder.recordUpdate(rowCount: 3, didReload: true, elapsedNanoseconds: 2_000_000)
    recorder.recordCellConfiguration()
    recorder.recordCellConfiguration()
    recorder.recordVisibleCellUpdates(5)
    recorder.recordIncrementalBatch(moveCount: 3, insertionCount: 2, removalCount: 1)
    recorder.recordUpdate(rowCount: 8, didReload: false, elapsedNanoseconds: 4_500_000)

    let metrics = recorder.drain()
    XCTAssertTrue(metrics.isMountedAtEnd)
    XCTAssertEqual(metrics.mountCount, 1)
    XCTAssertEqual(metrics.updateCount, 2)
    XCTAssertEqual(metrics.fullReloadCount, 1)
    XCTAssertEqual(metrics.incrementalBatchCount, 1)
    XCTAssertEqual(metrics.rowMoveCount, 3)
    XCTAssertEqual(metrics.rowInsertionCount, 2)
    XCTAssertEqual(metrics.rowRemovalCount, 1)
    XCTAssertEqual(metrics.cellConfigurationCount, 2)
    XCTAssertEqual(metrics.visibleCellUpdateCount, 5)
    XCTAssertEqual(metrics.rowCountRange, "3-8")
    XCTAssertEqual(metrics.totalUpdateMilliseconds, 6)
    XCTAssertEqual(metrics.maximumUpdateMilliseconds, 4)

    let next = recorder.drain()
    XCTAssertTrue(next.isMountedAtEnd)
    XCTAssertEqual(next.updateCount, 0)
    XCTAssertEqual(next.rowCountRange, "unknown")

    recorder.recordUnmount()
    let unmounted = recorder.drain()
    XCTAssertFalse(unmounted.isMountedAtEnd)
    XCTAssertEqual(unmounted.unmountCount, 1)
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
      connectionDecode: .empty,
      liveConnectionTable: .empty,
      liveTableFreezePhase: .disabled
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

  @MainActor
  func testLiveTableFreezeRequiresStableBaselineAndRestoresUpdates() {
    let experiment = LiveConnectionTableFreezeExperiment(isEnabled: true)
    let recorder = LiveConnectionTablePerformanceRecorder()

    recorder.recordMount()
    recorder.recordUpdate(rowCount: 8, didReload: true, elapsedNanoseconds: 1_000_000)
    XCTAssertEqual(experiment.completeInterval(recorder.drain()), .baseline)
    XCTAssertEqual(experiment.phase, .baseline)

    recorder.recordUpdate(rowCount: 8, didReload: false, elapsedNanoseconds: 1_000_000)
    XCTAssertEqual(experiment.completeInterval(recorder.drain()), .baseline)
    XCTAssertEqual(experiment.phase, .frozen)
    XCTAssertTrue(experiment.shouldSkipUpdate(hasExistingRows: true))
    XCTAssertFalse(experiment.shouldSkipUpdate(hasExistingRows: false))

    recorder.recordSkippedUpdate()
    XCTAssertEqual(recorder.drain().skippedUpdateCount, 1)
    XCTAssertEqual(experiment.completeInterval(.empty), .frozen)
    XCTAssertEqual(experiment.phase, .resumed)
    XCTAssertFalse(experiment.shouldSkipUpdate(hasExistingRows: true))
  }

  @MainActor
  func testLiveTableFreezeStaysDisabledWithoutFlag() {
    let experiment = LiveConnectionTableFreezeExperiment(isEnabled: false)
    XCTAssertEqual(experiment.completeInterval(.empty), .disabled)
    XCTAssertFalse(experiment.shouldSkipUpdate(hasExistingRows: true))
  }
}
