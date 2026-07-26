import Foundation

enum QuotaTrendEngine {
  static func calculate(
    snapshots: [SubscriptionQuotaSnapshot],
    window: QuotaTrendWindow,
    now: Date
  ) -> QuotaTrend {
    guard let latestSnapshot = snapshots.max(by: { $0.observedAt < $1.observedAt }) else {
      return .empty(window: window)
    }

    let windowStart = now.addingTimeInterval(-window.duration)
    let points =
      snapshots
      .filter { snapshot in
        snapshot.cycleID == latestSnapshot.cycleID
          && snapshot.effectiveAt >= windowStart
          && snapshot.effectiveAt <= now
      }
      .sorted { left, right in
        if left.effectiveAt == right.effectiveAt {
          return left.observedAt < right.observedAt
        }
        return left.effectiveAt < right.effectiveAt
      }
      .map {
        QuotaTrendPoint(id: $0.id, date: $0.effectiveAt, traffic: $0.traffic)
      }

    guard let first = points.first, let last = points.last, points.count >= 2 else {
      return QuotaTrend(
        window: window,
        points: points,
        consumedBytes: nil,
        dailyConsumptionBytes: nil,
        estimatedDepletionAt: nil
      )
    }
    let elapsed = last.date.timeIntervalSince(first.date)
    guard elapsed > 0, last.traffic.usedBytes >= first.traffic.usedBytes else {
      return QuotaTrend(
        window: window,
        points: points,
        consumedBytes: nil,
        dailyConsumptionBytes: nil,
        estimatedDepletionAt: nil
      )
    }

    let consumedBytes = last.traffic.usedBytes - first.traffic.usedBytes
    let dailyConsumptionBytes = Double(consumedBytes) / elapsed * 86_400
    let estimatedDepletionAt = depletionDate(
      remainingBytes: last.traffic.remainingBytes,
      dailyConsumptionBytes: dailyConsumptionBytes,
      now: now
    )
    return QuotaTrend(
      window: window,
      points: points,
      consumedBytes: consumedBytes,
      dailyConsumptionBytes: dailyConsumptionBytes,
      estimatedDepletionAt: estimatedDepletionAt
    )
  }

  private static func depletionDate(
    remainingBytes: UInt64,
    dailyConsumptionBytes: Double,
    now: Date
  ) -> Date? {
    guard dailyConsumptionBytes > 0 else {
      return nil
    }
    let remainingDays = Double(remainingBytes) / dailyConsumptionBytes
    let interval = remainingDays * 86_400
    guard interval.isFinite else {
      return nil
    }
    return now.addingTimeInterval(interval)
  }
}
