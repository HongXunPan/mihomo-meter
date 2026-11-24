struct ConnectionDecodeIntervalMetrics: Equatable, Sendable {
  static let empty = ConnectionDecodeIntervalMetrics(
    snapshotCount: 0,
    minimumConnectionCount: nil,
    maximumConnectionCount: nil,
    totalDecodeMilliseconds: 0,
    totalPayloadBytes: 0,
    totalConnectionEntries: 0,
    maximumDecodeMilliseconds: 0
  )

  let snapshotCount: Int
  let minimumConnectionCount: Int?
  let maximumConnectionCount: Int?
  let totalDecodeMilliseconds: Int
  let totalPayloadBytes: Int
  let totalConnectionEntries: Int
  let maximumDecodeMilliseconds: Int

  var connectionCountRange: String {
    guard let minimumConnectionCount, let maximumConnectionCount else {
      return "unknown"
    }
    return "\(minimumConnectionCount)-\(maximumConnectionCount)"
  }
}

actor ConnectionDecodePerformanceRecorder {
  static let shared = ConnectionDecodePerformanceRecorder()

  private var snapshotCount = 0
  private var minimumConnectionCount: Int?
  private var maximumConnectionCount: Int?
  private var totalDecodeNanoseconds: UInt64 = 0
  private var totalPayloadBytes = 0
  private var totalConnectionEntries = 0
  private var maximumDecodeNanoseconds: UInt64 = 0

  func record(connectionCount: Int, payloadByteCount: Int, elapsedNanoseconds: UInt64) {
    snapshotCount += 1
    minimumConnectionCount = min(minimumConnectionCount ?? connectionCount, connectionCount)
    maximumConnectionCount = max(maximumConnectionCount ?? connectionCount, connectionCount)
    totalDecodeNanoseconds += elapsedNanoseconds
    totalPayloadBytes += payloadByteCount
    totalConnectionEntries += connectionCount
    maximumDecodeNanoseconds = max(maximumDecodeNanoseconds, elapsedNanoseconds)
  }

  func drain() -> ConnectionDecodeIntervalMetrics {
    let metrics = ConnectionDecodeIntervalMetrics(
      snapshotCount: snapshotCount,
      minimumConnectionCount: minimumConnectionCount,
      maximumConnectionCount: maximumConnectionCount,
      totalDecodeMilliseconds: Int(totalDecodeNanoseconds / 1_000_000),
      totalPayloadBytes: totalPayloadBytes,
      totalConnectionEntries: totalConnectionEntries,
      maximumDecodeMilliseconds: Int(maximumDecodeNanoseconds / 1_000_000)
    )
    snapshotCount = 0
    minimumConnectionCount = nil
    maximumConnectionCount = nil
    totalDecodeNanoseconds = 0
    totalPayloadBytes = 0
    totalConnectionEntries = 0
    maximumDecodeNanoseconds = 0
    return metrics
  }
}
