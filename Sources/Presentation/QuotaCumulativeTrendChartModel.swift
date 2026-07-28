import Foundation

struct QuotaCumulativeTrendDelta: Equatable, Sendable {
  let uploadBytes: UInt64
  let downloadBytes: UInt64
  let totalBytes: UInt64
  let duration: TimeInterval
}

struct QuotaCumulativeTrendDisplayPoint: Identifiable, Equatable, Sendable {
  let point: QuotaTrendPoint
  let previousPoint: QuotaTrendPoint?
  let segmentStartPoint: QuotaTrendPoint

  var id: UUID {
    point.id
  }

  var delta: QuotaCumulativeTrendDelta? {
    guard let previousPoint,
      point.traffic.uploadBytes >= previousPoint.traffic.uploadBytes,
      point.traffic.downloadBytes >= previousPoint.traffic.downloadBytes
    else {
      return nil
    }

    let uploadBytes = point.traffic.uploadBytes - previousPoint.traffic.uploadBytes
    let downloadBytes = point.traffic.downloadBytes - previousPoint.traffic.downloadBytes
    return QuotaCumulativeTrendDelta(
      uploadBytes: uploadBytes,
      downloadBytes: downloadBytes,
      totalBytes: uploadBytes + downloadBytes,
      duration: point.date.timeIntervalSince(previousPoint.date)
    )
  }
}

struct QuotaCumulativeTrendDisplaySegment: Identifiable, Equatable, Sendable {
  struct ID: Hashable, Sendable {
    let cycleID: UUID
    let ordinal: Int
  }

  enum BreakReason: Equatable, Sendable {
    case cycleStart
    case counterRegression
  }

  let id: ID
  let breakReason: BreakReason
  let points: [QuotaCumulativeTrendDisplayPoint]
}

struct QuotaCumulativeTrendChartModel: Equatable, Sendable {
  static let minimumPointCount = 2
  static let maximumPointCount = 30
  static let preferredPointSpacing: Double = 40

  let segments: [QuotaCumulativeTrendDisplaySegment]
  let sourcePointCount: Int

  init(segments sourceSegments: [QuotaTrendSegment], targetPointCount: Int) {
    let splitSegments = Self.splitAtRegressions(sourceSegments)
    sourcePointCount = splitSegments.reduce(0) { $0 + $1.points.count }
    let selectedPointIDs = Self.selectedPointIDs(
      from: splitSegments,
      targetPointCount: targetPointCount
    )
    segments = splitSegments.compactMap { segment in
      guard let segmentStartPoint = segment.points.first else {
        return nil
      }
      var previousPoint: QuotaTrendPoint?
      let points = segment.points.compactMap { point -> QuotaCumulativeTrendDisplayPoint? in
        guard selectedPointIDs.contains(point.id) else {
          return nil
        }
        defer { previousPoint = point }
        return QuotaCumulativeTrendDisplayPoint(
          point: point,
          previousPoint: previousPoint,
          segmentStartPoint: segmentStartPoint
        )
      }
      guard !points.isEmpty else {
        return nil
      }
      return QuotaCumulativeTrendDisplaySegment(
        id: segment.id,
        breakReason: segment.breakReason,
        points: points
      )
    }
  }

  static func targetPointCount(for plotWidth: Double) -> Int {
    let estimatedCount = Int((plotWidth / preferredPointSpacing).rounded(.down))
    return min(max(estimatedCount, minimumPointCount), maximumPointCount)
  }

  var points: [QuotaCumulativeTrendDisplayPoint] {
    segments.flatMap(\.points)
  }

  var latestPoint: QuotaCumulativeTrendDisplayPoint? {
    points.max { $0.point.date < $1.point.date }
  }

  var dateDomain: ClosedRange<Date>? {
    guard let first = points.min(by: { $0.point.date < $1.point.date }),
      let last = points.max(by: { $0.point.date < $1.point.date }),
      first.point.date < last.point.date
    else {
      return nil
    }
    return first.point.date...last.point.date
  }

  var totalUsageDomain: ClosedRange<Double>? {
    let values = points.map { Double($0.point.traffic.usedBytes) }
    guard let minimum = values.min(), let maximum = values.max() else {
      return nil
    }

    let span = maximum - minimum
    let padding =
      span > 0
      ? max(span * 0.05, 1)
      : max(maximum * 0.01, 1)
    let lowerBound = max(minimum - padding, 0)
    return lowerBound...(maximum + padding)
  }

  func nearestPoint(to date: Date) -> QuotaCumulativeTrendDisplayPoint? {
    points.min { left, right in
      let leftDistance = abs(left.point.date.timeIntervalSince(date))
      let rightDistance = abs(right.point.date.timeIntervalSince(date))
      if leftDistance == rightDistance {
        return left.point.date < right.point.date
      }
      return leftDistance < rightDistance
    }
  }

  private struct SplitSegment {
    let id: QuotaCumulativeTrendDisplaySegment.ID
    let breakReason: QuotaCumulativeTrendDisplaySegment.BreakReason
    let points: [QuotaTrendPoint]
  }

  private static func splitAtRegressions(
    _ sourceSegments: [QuotaTrendSegment]
  ) -> [SplitSegment] {
    sourceSegments
      .sorted(by: segmentOrder)
      .flatMap { sourceSegment in
        splitAtRegressions(sourceSegment)
      }
  }

  private static func splitAtRegressions(
    _ sourceSegment: QuotaTrendSegment
  ) -> [SplitSegment] {
    var result: [SplitSegment] = []
    var currentPoints: [QuotaTrendPoint] = []
    var ordinal = 0
    let sortedPoints = sourceSegment.points.sorted(by: pointOrder)

    for point in sortedPoints {
      if let previous = currentPoints.last, isRegression(from: previous, to: point) {
        result.append(
          SplitSegment(
            id: .init(cycleID: sourceSegment.cycleID, ordinal: ordinal),
            breakReason: ordinal == 0 ? .cycleStart : .counterRegression,
            points: currentPoints
          )
        )
        ordinal += 1
        currentPoints = []
      }
      currentPoints.append(point)
    }

    if !currentPoints.isEmpty {
      result.append(
        SplitSegment(
          id: .init(cycleID: sourceSegment.cycleID, ordinal: ordinal),
          breakReason: ordinal == 0 ? .cycleStart : .counterRegression,
          points: currentPoints
        )
      )
    }
    return result
  }

  private static func selectedPointIDs(
    from segments: [SplitSegment],
    targetPointCount: Int
  ) -> Set<UUID> {
    let allPoints = segments.flatMap(\.points).sorted(by: pointOrder)
    let mandatoryPoints: [QuotaTrendPoint] = segments.flatMap { segment -> [QuotaTrendPoint] in
      guard let first = segment.points.first, let last = segment.points.last else {
        return []
      }
      return first.id == last.id ? [first] : [first, last]
    }
    var selectedIDs = Set(mandatoryPoints.map(\.id))
    let requestedCount = min(
      max(targetPointCount, minimumPointCount),
      maximumPointCount
    )
    let desiredCount = min(max(requestedCount, selectedIDs.count), allPoints.count)
    guard selectedIDs.count < desiredCount,
      let firstDate = allPoints.first?.date,
      let lastDate = allPoints.last?.date
    else {
      return selectedIDs
    }

    let additionalCount = desiredCount - selectedIDs.count
    let span = lastDate.timeIntervalSince(firstDate)
    for index in 1...additionalCount {
      let progress = Double(index) / Double(additionalCount + 1)
      let targetDate = firstDate.addingTimeInterval(span * progress)
      guard
        let nearest = nearestUnselectedPoint(
          to: targetDate,
          in: allPoints,
          excluding: selectedIDs
        )
      else {
        break
      }
      selectedIDs.insert(nearest.id)
    }
    return selectedIDs
  }

  private static func nearestUnselectedPoint(
    to date: Date,
    in points: [QuotaTrendPoint],
    excluding selectedIDs: Set<UUID>
  ) -> QuotaTrendPoint? {
    points
      .filter { !selectedIDs.contains($0.id) }
      .min { left, right in
        let leftDistance = abs(left.date.timeIntervalSince(date))
        let rightDistance = abs(right.date.timeIntervalSince(date))
        if leftDistance == rightDistance {
          return pointOrder(left, right)
        }
        return leftDistance < rightDistance
      }
  }

  private static func segmentOrder(
    _ left: QuotaTrendSegment,
    _ right: QuotaTrendSegment
  ) -> Bool {
    guard let leftDate = left.points.min(by: pointOrder)?.date else {
      return false
    }
    guard let rightDate = right.points.min(by: pointOrder)?.date else {
      return true
    }
    return leftDate < rightDate
  }

  private static func pointOrder(_ left: QuotaTrendPoint, _ right: QuotaTrendPoint) -> Bool {
    if left.date == right.date {
      return left.id.uuidString < right.id.uuidString
    }
    return left.date < right.date
  }

  private static func isRegression(
    from previous: QuotaTrendPoint,
    to current: QuotaTrendPoint
  ) -> Bool {
    current.traffic.uploadBytes < previous.traffic.uploadBytes
      || current.traffic.downloadBytes < previous.traffic.downloadBytes
  }
}
