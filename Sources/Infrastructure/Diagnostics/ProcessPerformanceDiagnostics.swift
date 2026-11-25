import Darwin
import Foundation

enum ProcessPerformanceDisplayMode: String, Sendable {
  case directDraw = "direct_draw"
  case nativeSingleLine = "native_single_line"
}

struct ProcessPerformanceSnapshot: Sendable {
  let uptimeSeconds: TimeInterval
  let cpuSeconds: TimeInterval
  let residentBytes: UInt64?
}

struct ProcessPerformanceSample: Sendable {
  let displayMode: ProcessPerformanceDisplayMode
  let cpuPercentTenths: Int
  let residentMiB: Int?
  let connectionDecode: ConnectionDecodeIntervalMetrics
  let liveConnectionTable: LiveConnectionTableIntervalMetrics
  let liveTableFreezePhase: LiveConnectionTableFreezePhase

  var logMessage: String {
    let resident = residentMiB.map(String.init) ?? "unknown"
    let tableMounted = liveConnectionTable.isMountedAtEnd ? 1 : 0
    return "event=performance.sample display_mode=\(displayMode.rawValue) "
      + "date_parser_mode=format_style "
      + "cpu_percent_tenths=\(cpuPercentTenths) rss_mib=\(resident)"
      + " connection_snapshots=\(connectionDecode.snapshotCount)"
      + " connection_count_range=\(connectionDecode.connectionCountRange)"
      + " connection_decode_ms=\(connectionDecode.totalDecodeMilliseconds)"
      + " snapshot_bytes_total=\(connectionDecode.totalPayloadBytes)"
      + " connection_entries_total=\(connectionDecode.totalConnectionEntries)"
      + " connection_decode_max_ms=\(connectionDecode.maximumDecodeMilliseconds)"
      + " live_table_mounted=\(tableMounted)"
      + " live_table_mounts=\(liveConnectionTable.mountCount)"
      + " live_table_unmounts=\(liveConnectionTable.unmountCount)"
      + " live_table_rows_range=\(liveConnectionTable.rowCountRange)"
      + " live_table_updates=\(liveConnectionTable.updateCount)"
      + " live_table_skipped_updates=\(liveConnectionTable.skippedUpdateCount)"
      + " live_table_reloads=\(liveConnectionTable.fullReloadCount)"
      + " live_table_incremental_batches=\(liveConnectionTable.incrementalBatchCount)"
      + " live_table_row_moves=\(liveConnectionTable.rowMoveCount)"
      + " live_table_row_insertions=\(liveConnectionTable.rowInsertionCount)"
      + " live_table_row_removals=\(liveConnectionTable.rowRemovalCount)"
      + " live_table_cells=\(liveConnectionTable.cellConfigurationCount)"
      + " live_table_visible_cell_updates=\(liveConnectionTable.visibleCellUpdateCount)"
      + " live_table_update_ms=\(liveConnectionTable.totalUpdateMilliseconds)"
      + " live_table_update_max_ms=\(liveConnectionTable.maximumUpdateMilliseconds)"
      + " live_table_freeze_phase=\(liveTableFreezePhase.rawValue)"
  }
}

enum ProcessPerformanceDiagnostics {
  static let enabledKey = "MIHOMO_METER_DIAG_PERFORMANCE"
  static let intervalSeconds = 60
  static let maximumSampleCount = 720

  static func startIfEnabled(
    variables: [String: String],
    logger: AppDiagnosticLogger
  ) -> Task<Void, Never>? {
    guard variables[enabledKey] == "1" else {
      return nil
    }

    let displayMode: ProcessPerformanceDisplayMode
    if variables["MIHOMO_METER_DIAG_NATIVE_STATUS_ITEM"] == "1" {
      displayMode = .nativeSingleLine
    } else {
      displayMode = .directDraw
    }
    return Task {
      guard var previous = snapshot() else {
        return
      }
      _ = await ConnectionDecodePerformanceRecorder.shared.drain()
      _ = await MainActor.run { LiveConnectionTablePerformanceRecorder.shared.drain() }
      for _ in 0..<maximumSampleCount {
        do {
          try await Task.sleep(for: .seconds(intervalSeconds))
        } catch {
          return
        }
        guard !Task.isCancelled, let current = snapshot() else {
          return
        }
        let connectionDecode = await ConnectionDecodePerformanceRecorder.shared.drain()
        let (liveConnectionTable, freezePhase) = await MainActor.run {
          let metrics = LiveConnectionTablePerformanceRecorder.shared.drain()
          let phase = LiveConnectionTableFreezeExperiment.shared.completeInterval(metrics)
          return (metrics, phase)
        }
        if let sample = sample(
          from: previous,
          to: current,
          displayMode: displayMode,
          connectionDecode: connectionDecode,
          liveConnectionTable: liveConnectionTable,
          liveTableFreezePhase: freezePhase
        ) {
          await logger.recordPerformance(sample)
        }
        previous = current
      }
    }
  }

  static func sample(
    from previous: ProcessPerformanceSnapshot,
    to current: ProcessPerformanceSnapshot,
    displayMode: ProcessPerformanceDisplayMode,
    connectionDecode: ConnectionDecodeIntervalMetrics,
    liveConnectionTable: LiveConnectionTableIntervalMetrics,
    liveTableFreezePhase: LiveConnectionTableFreezePhase
  ) -> ProcessPerformanceSample? {
    let elapsed = current.uptimeSeconds - previous.uptimeSeconds
    let cpuDelta = current.cpuSeconds - previous.cpuSeconds
    guard elapsed > 0, cpuDelta >= 0, elapsed.isFinite, cpuDelta.isFinite else {
      return nil
    }
    let cpuPercentTenths = Int((cpuDelta / elapsed * 1_000).rounded())
    let residentMiB = current.residentBytes.map { Int($0 / (1_024 * 1_024)) }
    return ProcessPerformanceSample(
      displayMode: displayMode,
      cpuPercentTenths: cpuPercentTenths,
      residentMiB: residentMiB,
      connectionDecode: connectionDecode,
      liveConnectionTable: liveConnectionTable,
      liveTableFreezePhase: liveTableFreezePhase
    )
  }

  private static func snapshot() -> ProcessPerformanceSnapshot? {
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else {
      return nil
    }
    let userSeconds = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
    let systemSeconds = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
    return ProcessPerformanceSnapshot(
      uptimeSeconds: ProcessInfo.processInfo.systemUptime,
      cpuSeconds: userSeconds + systemSeconds,
      residentBytes: residentBytes()
    )
  }

  private static func residentBytes() -> UInt64? {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
      MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &count)
      }
    }
    return result == KERN_SUCCESS ? UInt64(info.resident_size) : nil
  }
}
