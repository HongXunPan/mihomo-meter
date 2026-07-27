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
    guard let estimatedDepletionAt = trend.estimatedDepletionAt else {
      return "暂无耗尽预测"
    }
    let remainingDays = max(
      Int((estimatedDepletionAt.timeIntervalSinceNow / 86_400).rounded(.up)),
      0
    )
    return remainingDays == 0 ? "可能即将耗尽" : "预计可用约 \(remainingDays) 天"
  }
}
