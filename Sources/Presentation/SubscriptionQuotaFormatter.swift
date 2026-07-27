import Foundation

enum SubscriptionQuotaFormatter {
  static func bytes(_ value: UInt64) -> String {
    TrafficStatisticsFormatter.bytes(value)
  }

  static func updatedAt(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  static func expiration(_ date: Date?) -> String {
    guard let date else {
      return "未提供到期时间"
    }
    guard date > Date() else {
      return "已到期"
    }
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return "到期 \(formatter.string(from: date))"
  }

  static func refreshInterval(_ minutes: Int?) -> String {
    guard let minutes, minutes > 0 else {
      return "未设置查询周期"
    }
    return "每 \(minutes / 60) 小时查询"
  }

  static func consumption(_ trend: QuotaTrend) -> String {
    guard let consumedBytes = trend.consumedBytes else {
      return "样本积累中"
    }
    return "窗口内已用 \(bytes(consumedBytes))"
  }

  static func depletion(_ trend: QuotaTrend) -> String {
    switch trend.depletionForecast {
    case .available(let estimatedDepletionAt):
      let remainingDays = max(
        Int((estimatedDepletionAt.timeIntervalSinceNow / 86_400).rounded(.up)),
        0
      )
      return remainingDays == 0 ? "可能即将耗尽" : "预计可用约 \(remainingDays) 天"
    case .unavailable(let reason):
      switch reason {
      case .insufficientSamples:
        return "样本不足，暂不预测"
      case .insufficientObservationSpan:
        return "观察不足 6 小时"
      case .staleData:
        return "数据已过期，暂不预测"
      case .unconfirmedCycle:
        return "待确认新周期"
      case .noRecentConsumption:
        return "近期无消耗"
      case .expired:
        return "订阅已到期"
      case .depleted:
        return "额度已耗尽"
      }
    }
  }

  static func quotaEvent(_ event: QuotaEvent) -> String {
    switch event.kind {
    case .usageReset:
      "检测到用量重置"
    case .totalIncreased:
      "检测到总额度增加"
    case .totalDecreased:
      "检测到总额度减少"
    case .expirationChanged:
      "检测到到期时间变化"
    }
  }
}
