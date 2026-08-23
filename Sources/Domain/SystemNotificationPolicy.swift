import Foundation

enum SystemNotificationAuthorization: Equatable, Sendable {
  case unknown
  case notDetermined
  case authorized
  case denied
}

enum QuotaNotificationKind: String, CaseIterable, Equatable, Sendable {
  case lowRemaining
  case expiringSoon
  case depletingSoon
}

struct SystemNotificationDelivery: Equatable, Sendable {
  let deduplicationKey: String
  let title: String
  let body: String
  let target: AppActivationTarget
}

struct QuotaNotificationInput: Equatable, Sendable {
  let subscriptionID: UUID
  let cycleID: UUID
  let isCurrentCycleConfirmed: Bool
  let observedAt: Date
  let traffic: QuotaTraffic
  let expireAt: Date?
  let estimatedDepletionAt: Date?
}

enum QuotaSystemNotificationPolicy {
  static let maximumSnapshotAge: TimeInterval = 15 * 60
  static let upcomingInterval: TimeInterval = 3 * 24 * 60 * 60

  static func deliveries(
    for inputs: [QuotaNotificationInput],
    at now: Date
  ) -> [SystemNotificationDelivery] {
    inputs.flatMap { input in
      guard input.isCurrentCycleConfirmed, isFresh(input.observedAt, at: now) else {
        return []
      }

      var deliveries: [SystemNotificationDelivery] = []
      if input.traffic.remainingBytes <= input.traffic.totalBytes / 10 {
        deliveries.append(delivery(for: input, kind: .lowRemaining))
      }
      if isUpcoming(input.expireAt, at: now) {
        deliveries.append(delivery(for: input, kind: .expiringSoon))
      }
      if isUpcoming(input.estimatedDepletionAt, at: now) {
        deliveries.append(delivery(for: input, kind: .depletingSoon))
      }
      return deliveries
    }
  }

  private static func isFresh(_ observedAt: Date, at now: Date) -> Bool {
    observedAt <= now && now.timeIntervalSince(observedAt) <= maximumSnapshotAge
  }

  private static func isUpcoming(_ date: Date?, at now: Date) -> Bool {
    guard let date else {
      return false
    }
    return date > now && date.timeIntervalSince(now) <= upcomingInterval
  }

  private static func delivery(
    for input: QuotaNotificationInput,
    kind: QuotaNotificationKind
  ) -> SystemNotificationDelivery {
    let key = [
      "quota",
      input.subscriptionID.uuidString.lowercased(),
      input.cycleID.uuidString.lowercased(),
      kind.rawValue,
    ].joined(separator: "|")
    switch kind {
    case .lowRemaining:
      return SystemNotificationDelivery(
        deduplicationKey: key,
        title: "订阅配额不足",
        body: "有一项订阅的剩余配额已不高于 10%，请打开订阅余额查看。",
        target: .subscriptionQuota
      )
    case .expiringSoon:
      return SystemNotificationDelivery(
        deduplicationKey: key,
        title: "订阅即将过期",
        body: "有一项订阅将在 3 天内过期，请打开订阅余额查看。",
        target: .subscriptionQuota
      )
    case .depletingSoon:
      return SystemNotificationDelivery(
        deduplicationKey: key,
        title: "订阅配额预计即将耗尽",
        body: "有一项订阅预计将在 3 天内耗尽，请打开订阅余额查看。",
        target: .subscriptionQuota
      )
    }
  }
}

enum ConnectionSystemNotificationPolicy {
  static let sustainedDisconnectionInterval: TimeInterval = 10 * 60
  static let deduplicationKey = "connection|sustained-disconnection"

  static func shouldNotify(disconnectedSince: Date?, at now: Date) -> Bool {
    guard let disconnectedSince, disconnectedSince <= now else {
      return false
    }
    return now.timeIntervalSince(disconnectedSince) >= sustainedDisconnectionInterval
  }

  static let delivery = SystemNotificationDelivery(
    deduplicationKey: deduplicationKey,
    title: "Mihomo 连接持续中断",
    body: "连接已连续 10 分钟未恢复，请打开连接设置检查。",
    target: .controllerSettings
  )
}

extension QuotaDepletionForecast {
  var notificationEstimatedAt: Date? {
    guard case .available(let date) = self else {
      return nil
    }
    return date
  }
}
