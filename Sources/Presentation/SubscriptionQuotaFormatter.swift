import Foundation

enum SubscriptionQuotaFormatter {
  static func bytes(_ value: UInt64) -> String {
    TrafficStatisticsFormatter.bytes(value)
  }

  static func updatedAt(_ date: Date) -> String {
    relativeDate(date, relativeTo: Date())
  }

  static func relativeDate(_ date: Date, relativeTo referenceDate: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "zh_Hans_CN")
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: referenceDate)
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

  static func usageSummary(_ series: QuotaUsageSeries) -> String {
    guard !series.bars.isEmpty else {
      return series.unresolvedIntervals.isEmpty ? "样本积累中" : "存在无法拆分区间"
    }
    let total = series.totalDownloadBytes + series.totalUploadBytes
    let prefix = series.unresolvedIntervals.isEmpty ? "已记录新增" : "可比较新增"
    guard let coverageDuration = series.coverageDuration else {
      return "\(prefix) \(bytes(total))"
    }
    return "\(prefix) \(bytes(total)) · 覆盖 \(duration(coverageDuration))"
  }

  static func unresolvedInterval(
    _ interval: QuotaUsageInterval,
    additionalCount: Int
  ) -> String {
    let formatter = DateIntervalFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    let range = formatter.string(from: interval.startAt, to: interval.endAt)
    let suffix = additionalCount > 0 ? "，另有 \(additionalCount) 段" : ""
    return "\(range) · \(duration(interval.duration))合计 ↓"
      + "\(bytes(interval.downloadBytes)) ↑\(bytes(interval.uploadBytes))\(suffix)"
  }

  static func usageTick(
    _ date: Date,
    aggregation: QuotaUsageAggregation
  ) -> String {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.timeZone = .autoupdatingCurrent
    switch aggregation {
    case .automatic, .hour, .threeHour, .sixHour, .twelveHour:
      formatter.setLocalizedDateFormatFromTemplate("MdHH")
    case .day, .week:
      formatter.setLocalizedDateFormatFromTemplate("Md")
    case .month:
      formatter.setLocalizedDateFormatFromTemplate("yyyyM")
    }
    return formatter.string(from: date)
  }

  static func usageBucket(
    _ interval: DateInterval,
    aggregation: QuotaUsageAggregation
  ) -> String {
    switch aggregation {
    case .automatic, .hour, .threeHour, .sixHour, .twelveHour:
      let date = usageDate(interval.start, template: "Md")
      let start = usageDate(interval.start, template: "HHmm")
      let end = usageDate(interval.end, template: "HHmm")
      return "\(date) \(start)–\(end)"
    case .day:
      return usageDate(interval.start, template: "yyyyMd")
    case .week:
      let formatter = DateIntervalFormatter()
      formatter.locale = .autoupdatingCurrent
      formatter.timeZone = .autoupdatingCurrent
      formatter.dateStyle = .short
      formatter.timeStyle = .none
      return formatter.string(from: interval.start, to: interval.end.addingTimeInterval(-0.001))
    case .month:
      return usageDate(interval.start, template: "yyyyM")
    }
  }

  static func trendTimestamp(_ date: Date) -> String {
    usageDate(date, template: "yyyyMdHHmm")
  }

  static func trendTick(_ date: Date, window: QuotaTrendWindow) -> String {
    switch window {
    case .day, .week:
      usageDate(date, template: "MdHH")
    case .month:
      usageDate(date, template: "Md")
    case .year:
      usageDate(date, template: "yyyyM")
    }
  }

  static func trendCoverage(
    from start: Date,
    to end: Date,
    displayedPointCount: Int,
    sourcePointCount: Int
  ) -> String {
    "覆盖 \(trendTimestamp(start))–\(trendTimestamp(end)) · "
      + "展示 \(displayedPointCount)/\(sourcePointCount) 个真实快照"
  }

  static func preciseDuration(_ interval: TimeInterval) -> String {
    guard interval >= 60 else {
      return "不足 1 分钟"
    }
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.day, .hour, .minute]
    formatter.maximumUnitCount = 2
    formatter.zeroFormattingBehavior = .dropAll
    return formatter.string(from: interval) ?? duration(interval)
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

  private static func duration(_ interval: TimeInterval) -> String {
    let hours = max(Int((interval / 3_600).rounded()), 1)
    if hours.isMultiple(of: 24) {
      return "\(hours / 24) 天"
    }
    return "\(hours) 小时"
  }

  private static func usageDate(_ date: Date, template: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.timeZone = .autoupdatingCurrent
    formatter.setLocalizedDateFormatFromTemplate(template)
    return formatter.string(from: date)
  }
}

extension QuotaUsageAggregation {
  var title: String {
    switch self {
    case .automatic:
      "自动"
    case .hour:
      "小时"
    case .threeHour:
      "3 小时"
    case .sixHour:
      "6 小时"
    case .twelveHour:
      "12 小时"
    case .day:
      "天"
    case .week:
      "周"
    case .month:
      "月"
    }
  }
}
