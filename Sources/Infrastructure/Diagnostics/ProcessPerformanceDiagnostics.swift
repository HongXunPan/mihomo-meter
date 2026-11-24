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

  var logMessage: String {
    let resident = residentMiB.map(String.init) ?? "unknown"
    return "event=performance.sample display_mode=\(displayMode.rawValue) "
      + "date_parser_mode=format_style "
      + "cpu_percent_tenths=\(cpuPercentTenths) rss_mib=\(resident)"
      + " connection_snapshots=\(connectionDecode.snapshotCount)"
      + " connection_count_range=\(connectionDecode.connectionCountRange)"
      + " connection_decode_ms=\(connectionDecode.totalDecodeMilliseconds)"
      + " snapshot_bytes_total=\(connectionDecode.totalPayloadBytes)"
      + " connection_entries_total=\(connectionDecode.totalConnectionEntries)"
      + " connection_decode_max_ms=\(connectionDecode.maximumDecodeMilliseconds)"
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
        if let sample = sample(
          from: previous,
          to: current,
          displayMode: displayMode,
          connectionDecode: connectionDecode
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
    connectionDecode: ConnectionDecodeIntervalMetrics
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
      connectionDecode: connectionDecode
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
