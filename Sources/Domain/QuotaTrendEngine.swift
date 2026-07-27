import Foundation

enum QuotaTrendEngine {
  static let minimumObservationSpan: TimeInterval = 6 * 60 * 60

  static func calculate(
    snapshots: [SubscriptionQuotaSnapshot],
    window: QuotaTrendWindow,
    now: Date,
    context: QuotaTrendContext
  ) -> QuotaTrend {
    guard let latestSnapshot = context.latestSnapshot else {
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
        depletionForecast: unavailableForecast(
          latestSnapshot: latestSnapshot,
          context: context,
          now: now,
          fallback: .insufficientSamples
        )
      )
    }
    let elapsed = last.date.timeIntervalSince(first.date)
    guard elapsed >= minimumObservationSpan else {
      return QuotaTrend(
        window: window,
        points: points,
        consumedBytes: nil,
        dailyConsumptionBytes: nil,
        depletionForecast: unavailableForecast(
          latestSnapshot: latestSnapshot,
          context: context,
          now: now,
          fallback: .insufficientObservationSpan
        )
      )
    }
    guard last.traffic.usedBytes >= first.traffic.usedBytes else {
      return QuotaTrend(
        window: window,
        points: points,
        consumedBytes: nil,
        dailyConsumptionBytes: nil,
        depletionForecast: .unavailable(.unconfirmedCycle)
      )
    }

    let consumedBytes = last.traffic.usedBytes - first.traffic.usedBytes
    let dailyConsumptionBytes = Double(consumedBytes) / elapsed * 86_400
    let depletionForecast = forecast(
      latestSnapshot: latestSnapshot,
      context: context,
      remainingBytes: last.traffic.remainingBytes,
      dailyConsumptionBytes: dailyConsumptionBytes,
      latestEffectiveAt: last.date,
      now: now
    )
    return QuotaTrend(
      window: window,
      points: points,
      consumedBytes: consumedBytes,
      dailyConsumptionBytes: dailyConsumptionBytes,
      depletionForecast: depletionForecast
    )
  }

  private static func forecast(
    latestSnapshot: SubscriptionQuotaSnapshot,
    context: QuotaTrendContext,
    remainingBytes: UInt64,
    dailyConsumptionBytes: Double,
    latestEffectiveAt: Date,
    now: Date
  ) -> QuotaDepletionForecast {
    if let unavailable = primaryUnavailableReason(
      latestSnapshot: latestSnapshot,
      context: context,
      now: now
    ) {
      return .unavailable(unavailable)
    }
    guard dailyConsumptionBytes > 0 else {
      return .unavailable(.noRecentConsumption)
    }
    let remainingDays = Double(remainingBytes) / dailyConsumptionBytes
    let interval = remainingDays * 86_400
    guard interval.isFinite else {
      return .unavailable(.noRecentConsumption)
    }
    return .available(latestEffectiveAt.addingTimeInterval(interval))
  }

  private static func unavailableForecast(
    latestSnapshot: SubscriptionQuotaSnapshot,
    context: QuotaTrendContext,
    now: Date,
    fallback: QuotaForecastUnavailableReason
  ) -> QuotaDepletionForecast {
    .unavailable(
      primaryUnavailableReason(
        latestSnapshot: latestSnapshot,
        context: context,
        now: now
      ) ?? fallback
    )
  }

  private static func primaryUnavailableReason(
    latestSnapshot: SubscriptionQuotaSnapshot,
    context: QuotaTrendContext,
    now: Date
  ) -> QuotaForecastUnavailableReason? {
    if latestSnapshot.expireAt.map({ $0 <= now }) == true {
      return .expired
    }
    if latestSnapshot.traffic.remainingBytes == 0 {
      return .depleted
    }
    if now.timeIntervalSince(latestSnapshot.effectiveAt) > context.maximumDataAge {
      return .staleData
    }
    guard
      let currentCycle = context.currentCycle,
      currentCycle.id == latestSnapshot.cycleID,
      currentCycle.isUserConfirmed
    else {
      return .unconfirmedCycle
    }
    return nil
  }
}
