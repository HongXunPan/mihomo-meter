import Foundation

enum SystemNotificationInputBuilder {
  static func inputs(
    runtime: RuntimeQuotaTrackingSnapshot,
    profiles: ProfileQuotaTrackingSnapshot
  ) -> [QuotaNotificationInput] {
    runtimeInputs(runtime) + profileInputs(profiles)
  }

  private static func runtimeInputs(
    _ snapshot: RuntimeQuotaTrackingSnapshot
  ) -> [QuotaNotificationInput] {
    guard
      let subscription = snapshot.subscription,
      subscription.status == .active,
      let input = input(
        subscriptionID: subscription.id,
        analysis: snapshot.analysis
      )
    else {
      return []
    }
    return [input]
  }

  private static func profileInputs(
    _ snapshot: ProfileQuotaTrackingSnapshot
  ) -> [QuotaNotificationInput] {
    snapshot.profiles.compactMap { item in
      guard item.subscription.status == .active else {
        return nil
      }
      return input(subscriptionID: item.subscription.id, analysis: item.analysis)
    }
  }

  private static func input(
    subscriptionID: UUID,
    analysis: SubscriptionQuotaAnalysis
  ) -> QuotaNotificationInput? {
    guard
      let snapshot = analysis.latestQuota,
      let cycle = analysis.currentCycle,
      cycle.id == snapshot.cycleID
    else {
      return nil
    }
    return QuotaNotificationInput(
      subscriptionID: subscriptionID,
      cycleID: cycle.id,
      isCurrentCycleConfirmed: cycle.isUserConfirmed,
      observedAt: snapshot.observedAt,
      traffic: snapshot.traffic,
      expireAt: snapshot.expireAt,
      estimatedDepletionAt: analysis.trends.depletionForecast.notificationEstimatedAt
    )
  }
}
