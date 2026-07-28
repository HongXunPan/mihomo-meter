import Foundation

enum QuotaUsageTrendEngine {
  static func calculate(
    snapshots: [SubscriptionQuotaSnapshot],
    windowStart: Date,
    windowEnd: Date,
    calendar: Calendar
  ) -> [QuotaUsageAggregation: QuotaUsageSeries] {
    let intervals = intervals(
      snapshots: snapshots,
      windowStart: windowStart,
      windowEnd: windowEnd
    )
    let manualSeries = Dictionary(
      uniqueKeysWithValues: QuotaUsageAggregation.calculationCases.map { aggregation in
        (
          aggregation,
          QuotaUsageAggregator.calendarSeries(
            intervals: intervals,
            aggregation: aggregation,
            rangeStart: windowStart,
            rangeEnd: windowEnd,
            calendar: calendar
          )
        )
      }
    )
    let automatic = automaticSeries(
      manualSeries: manualSeries,
      rangeStart: windowStart,
      rangeEnd: windowEnd
    )
    return manualSeries.merging([.automatic: automatic]) { current, _ in current }
  }

  private static func intervals(
    snapshots: [SubscriptionQuotaSnapshot],
    windowStart: Date,
    windowEnd: Date
  ) -> [QuotaUsageInterval] {
    Dictionary(
      grouping: snapshots.filter {
        $0.effectiveAt >= windowStart && $0.effectiveAt <= windowEnd
      },
      by: \.cycleID
    )
    .values
    .flatMap { cycleSnapshots in
      let ordered = cycleSnapshots.sorted(by: snapshotOrder)
      return zip(ordered, ordered.dropFirst()).compactMap { previous, current in
        makeInterval(previous: previous, current: current)
      }
    }
    .sorted { left, right in
      if left.endAt == right.endAt {
        return left.startAt < right.startAt
      }
      return left.endAt < right.endAt
    }
  }

  private static func makeInterval(
    previous: SubscriptionQuotaSnapshot,
    current: SubscriptionQuotaSnapshot
  ) -> QuotaUsageInterval? {
    guard
      current.effectiveAt > previous.effectiveAt,
      current.traffic.uploadBytes >= previous.traffic.uploadBytes,
      current.traffic.downloadBytes >= previous.traffic.downloadBytes
    else {
      return nil
    }
    return QuotaUsageInterval(
      id: current.id,
      cycleID: current.cycleID,
      startAt: previous.effectiveAt,
      endAt: current.effectiveAt,
      uploadBytes: current.traffic.uploadBytes - previous.traffic.uploadBytes,
      downloadBytes: current.traffic.downloadBytes - previous.traffic.downloadBytes
    )
  }

  private static func snapshotOrder(
    left: SubscriptionQuotaSnapshot,
    right: SubscriptionQuotaSnapshot
  ) -> Bool {
    if left.effectiveAt == right.effectiveAt {
      if left.observedAt == right.observedAt {
        return left.id.uuidString < right.id.uuidString
      }
      return left.observedAt < right.observedAt
    }
    return left.effectiveAt < right.effectiveAt
  }

  private static func automaticSeries(
    manualSeries: [QuotaUsageAggregation: QuotaUsageSeries],
    rangeStart: Date,
    rangeEnd: Date
  ) -> QuotaUsageSeries {
    let rangeDuration = rangeEnd.timeIntervalSince(rangeStart)
    let candidates: [QuotaUsageSeries] =
      QuotaUsageAggregation.calculationCases.compactMap { aggregation -> QuotaUsageSeries? in
        guard aggregation.nominalDuration <= rangeDuration,
          let series = manualSeries[aggregation],
          !series.bars.isEmpty
        else {
          return nil
        }
        return series
      }
    guard let selected = candidates.min(by: { score($0) < score($1) }) else {
      let fallback = manualSeries[.hour] ?? .empty(aggregation: .hour)
      return QuotaUsageSeries(
        requestedAggregation: .automatic,
        resolvedAggregation: fallback.resolvedAggregation,
        bars: [],
        unresolvedIntervals: fallback.unresolvedIntervals,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd
      )
    }
    return QuotaUsageSeries(
      requestedAggregation: .automatic,
      resolvedAggregation: selected.resolvedAggregation,
      bars: selected.bars,
      unresolvedIntervals: selected.unresolvedIntervals,
      rangeStart: selected.rangeStart,
      rangeEnd: selected.rangeEnd
    )
  }

  private static func score(_ series: QuotaUsageSeries) -> Int {
    let count = series.bars.count
    let countPenalty = count >= 8 && count <= 30 ? abs(20 - count) : 100 + abs(20 - count)
    return countPenalty + series.unresolvedIntervals.count * 4
  }
}
