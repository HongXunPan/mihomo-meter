import Foundation

enum QuotaUsageAggregator {
  static func calendarSeries(
    intervals: [QuotaUsageInterval],
    aggregation: QuotaUsageAggregation,
    rangeStart: Date,
    rangeEnd: Date,
    calendar: Calendar
  ) -> QuotaUsageSeries {
    let visibleBucketStarts = Set(
      bucketIntervals(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        aggregation: aggregation,
        calendar: calendar
      ).map(\.start)
    )
    var buckets: [Date: QuotaUsageBucketAccumulator] = [:]
    var unresolved: [QuotaUsageInterval] = []
    for interval in intervals {
      guard
        let bucket = bucketInterval(
          containingIntervalEnd: interval.endAt,
          aggregation: aggregation,
          calendar: calendar
        )
      else {
        unresolved.append(interval)
        continue
      }
      guard visibleBucketStarts.contains(bucket.start) else {
        continue
      }
      let staysInsideBucket = interval.startAt >= bucket.start
      let canUseBoundaryApproximation = interval.duration < bucket.duration
      guard staysInsideBucket || canUseBoundaryApproximation else {
        unresolved.append(interval)
        continue
      }
      var accumulator =
        buckets[bucket.start] ?? QuotaUsageBucketAccumulator(interval: bucket)
      accumulator.append(
        interval,
        isBoundaryApproximation: !staysInsideBucket
      )
      buckets[bucket.start] = accumulator
    }
    return QuotaUsageSeries(
      requestedAggregation: aggregation,
      resolvedAggregation: aggregation,
      bars: buckets.values.map(\.bar).sorted { $0.startAt < $1.startAt },
      unresolvedIntervals: unresolved,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd
    )
  }

  static func bucketIntervals(
    rangeStart: Date,
    rangeEnd: Date,
    aggregation: QuotaUsageAggregation,
    calendar: Calendar
  ) -> [DateInterval] {
    guard rangeStart < rangeEnd,
      let firstCandidate = bucketInterval(
        containing: rangeStart,
        aggregation: aggregation,
        calendar: calendar
      )
    else {
      return []
    }
    let startsAtBoundary = firstCandidate.start == rangeStart
    guard
      var bucket = startsAtBoundary
        ? firstCandidate
        : bucketInterval(
          containing: firstCandidate.end.addingTimeInterval(0.001),
          aggregation: aggregation,
          calendar: calendar
        )
    else {
      return []
    }
    var intervals: [DateInterval] = []
    while bucket.start < rangeEnd {
      intervals.append(bucket)
      guard
        let next = bucketInterval(
          containing: bucket.end.addingTimeInterval(0.001),
          aggregation: aggregation,
          calendar: calendar
        ),
        next.start > bucket.start
      else {
        break
      }
      bucket = next
    }
    return intervals
  }

  private static func bucketInterval(
    containingIntervalEnd endAt: Date,
    aggregation: QuotaUsageAggregation,
    calendar: Calendar
  ) -> DateInterval? {
    bucketInterval(
      containing: endAt.addingTimeInterval(-0.001),
      aggregation: aggregation,
      calendar: calendar
    )
  }

  private static func bucketInterval(
    containing date: Date,
    aggregation: QuotaUsageAggregation,
    calendar: Calendar
  ) -> DateInterval? {
    switch aggregation {
    case .automatic:
      return nil
    case .hour:
      return fixedHourInterval(containing: date, hours: 1, calendar: calendar)
    case .threeHour:
      return fixedHourInterval(containing: date, hours: 3, calendar: calendar)
    case .sixHour:
      return fixedHourInterval(containing: date, hours: 6, calendar: calendar)
    case .twelveHour:
      return fixedHourInterval(containing: date, hours: 12, calendar: calendar)
    case .day:
      return calendar.dateInterval(of: .day, for: date)
    case .week:
      return calendar.dateInterval(of: .weekOfYear, for: date)
    case .month:
      return calendar.dateInterval(of: .month, for: date)
    }
  }

  private static func fixedHourInterval(
    containing date: Date,
    hours: Int,
    calendar: Calendar
  ) -> DateInterval? {
    let dayStart = calendar.startOfDay(for: date)
    guard
      let elapsedHours = calendar.dateComponents([.hour], from: dayStart, to: date).hour,
      let start = calendar.date(
        byAdding: .hour,
        value: elapsedHours / hours * hours,
        to: dayStart
      ),
      let end = calendar.date(byAdding: .hour, value: hours, to: start)
    else {
      return nil
    }
    return DateInterval(start: start, end: end)
  }
}

private struct QuotaUsageBucketAccumulator {
  let interval: DateInterval
  private(set) var uploadBytes: UInt64 = 0
  private(set) var downloadBytes: UInt64 = 0
  private(set) var intervalCount = 0
  private(set) var isBoundaryApproximation = false

  mutating func append(
    _ usageInterval: QuotaUsageInterval,
    isBoundaryApproximation: Bool
  ) {
    uploadBytes += usageInterval.uploadBytes
    downloadBytes += usageInterval.downloadBytes
    intervalCount += 1
    self.isBoundaryApproximation =
      self.isBoundaryApproximation || isBoundaryApproximation
  }

  var bar: QuotaUsageBar {
    QuotaUsageBar(
      id: QuotaUsagePeriodID(startAt: interval.start, endAt: interval.end),
      startAt: interval.start,
      endAt: interval.end,
      uploadBytes: uploadBytes,
      downloadBytes: downloadBytes,
      intervalCount: intervalCount,
      isBoundaryApproximation: isBoundaryApproximation
    )
  }
}
