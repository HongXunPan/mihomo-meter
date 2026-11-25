struct LiveConnectionTableIntervalMetrics: Equatable, Sendable {
  static let empty = LiveConnectionTableIntervalMetrics(
    isMountedAtEnd: false,
    mountCount: 0,
    unmountCount: 0,
    updateCount: 0,
    skippedUpdateCount: 0,
    fullReloadCount: 0,
    incrementalBatchCount: 0,
    rowMoveCount: 0,
    rowInsertionCount: 0,
    rowRemovalCount: 0,
    cellConfigurationCount: 0,
    visibleCellUpdateCount: 0,
    minimumRowCount: nil,
    maximumRowCount: nil,
    totalUpdateMilliseconds: 0,
    maximumUpdateMilliseconds: 0
  )

  let isMountedAtEnd: Bool
  let mountCount: Int
  let unmountCount: Int
  let updateCount: Int
  let skippedUpdateCount: Int
  let fullReloadCount: Int
  let incrementalBatchCount: Int
  let rowMoveCount: Int
  let rowInsertionCount: Int
  let rowRemovalCount: Int
  let cellConfigurationCount: Int
  let visibleCellUpdateCount: Int
  let minimumRowCount: Int?
  let maximumRowCount: Int?
  let totalUpdateMilliseconds: Int
  let maximumUpdateMilliseconds: Int

  var rowCountRange: String {
    guard let minimumRowCount, let maximumRowCount else {
      return "unknown"
    }
    return "\(minimumRowCount)-\(maximumRowCount)"
  }
}

@MainActor
final class LiveConnectionTablePerformanceRecorder {
  static let shared = LiveConnectionTablePerformanceRecorder()

  private var mountedViewCount = 0
  private var mountCount = 0
  private var unmountCount = 0
  private var updateCount = 0
  private var skippedUpdateCount = 0
  private var fullReloadCount = 0
  private var incrementalBatchCount = 0
  private var rowMoveCount = 0
  private var rowInsertionCount = 0
  private var rowRemovalCount = 0
  private var cellConfigurationCount = 0
  private var visibleCellUpdateCount = 0
  private var minimumRowCount: Int?
  private var maximumRowCount: Int?
  private var totalUpdateNanoseconds: UInt64 = 0
  private var maximumUpdateNanoseconds: UInt64 = 0

  func recordMount() {
    mountedViewCount += 1
    mountCount += 1
  }

  func recordUnmount() {
    mountedViewCount = max(mountedViewCount - 1, 0)
    unmountCount += 1
  }

  func recordCellConfiguration() {
    cellConfigurationCount += 1
  }

  func recordVisibleCellUpdates(_ count: Int) {
    visibleCellUpdateCount += count
  }

  func recordSkippedUpdate() {
    skippedUpdateCount += 1
  }

  func recordIncrementalBatch(moveCount: Int, insertionCount: Int, removalCount: Int) {
    incrementalBatchCount += 1
    rowMoveCount += moveCount
    rowInsertionCount += insertionCount
    rowRemovalCount += removalCount
  }

  func recordUpdate(
    rowCount: Int,
    didReload: Bool,
    elapsedNanoseconds: UInt64
  ) {
    updateCount += 1
    if didReload {
      fullReloadCount += 1
    }
    minimumRowCount = min(minimumRowCount ?? rowCount, rowCount)
    maximumRowCount = max(maximumRowCount ?? rowCount, rowCount)
    totalUpdateNanoseconds += elapsedNanoseconds
    maximumUpdateNanoseconds = max(maximumUpdateNanoseconds, elapsedNanoseconds)
  }

  func drain() -> LiveConnectionTableIntervalMetrics {
    let metrics = LiveConnectionTableIntervalMetrics(
      isMountedAtEnd: mountedViewCount > 0,
      mountCount: mountCount,
      unmountCount: unmountCount,
      updateCount: updateCount,
      skippedUpdateCount: skippedUpdateCount,
      fullReloadCount: fullReloadCount,
      incrementalBatchCount: incrementalBatchCount,
      rowMoveCount: rowMoveCount,
      rowInsertionCount: rowInsertionCount,
      rowRemovalCount: rowRemovalCount,
      cellConfigurationCount: cellConfigurationCount,
      visibleCellUpdateCount: visibleCellUpdateCount,
      minimumRowCount: minimumRowCount,
      maximumRowCount: maximumRowCount,
      totalUpdateMilliseconds: Int(totalUpdateNanoseconds / 1_000_000),
      maximumUpdateMilliseconds: Int(maximumUpdateNanoseconds / 1_000_000)
    )
    mountCount = 0
    unmountCount = 0
    updateCount = 0
    skippedUpdateCount = 0
    fullReloadCount = 0
    incrementalBatchCount = 0
    rowMoveCount = 0
    rowInsertionCount = 0
    rowRemovalCount = 0
    cellConfigurationCount = 0
    visibleCellUpdateCount = 0
    minimumRowCount = nil
    maximumRowCount = nil
    totalUpdateNanoseconds = 0
    maximumUpdateNanoseconds = 0
    return metrics
  }
}
