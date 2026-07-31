import SwiftUI

enum ProfileQuotaStatusTone {
  case neutral
  case positive
  case waiting
  case warning
  case negative

  var color: Color {
    switch self {
    case .neutral:
      MihomoColorToken.statusNeutral
    case .positive:
      MihomoColorToken.statusSuccess
    case .waiting:
      MihomoColorToken.brandPrimary
    case .warning:
      MihomoColorToken.statusWarning
    case .negative:
      MihomoColorToken.statusDanger
    }
  }
}

struct ProfileQuotaStatusPresentation {
  let title: String
  let message: String
  let compactSummary: String
  let symbolName: String
  let tone: ProfileQuotaStatusTone
  let overridesForecast: Bool

  private init(
    title: String,
    message: String,
    compactSummary: String? = nil,
    symbolName: String,
    tone: ProfileQuotaStatusTone,
    overridesForecast: Bool = false
  ) {
    self.title = title
    self.message = message
    self.compactSummary = compactSummary ?? title
    self.symbolName = symbolName
    self.tone = tone
    self.overridesForecast = overridesForecast
  }

  init(item: ProfileQuotaTrackingItem, relativeTo date: Date = Date()) {
    switch item.queryStatus {
    case .unavailableProfile:
      self = Self.unavailableProfile(
        item.availability,
        latestQuota: item.latestQuota,
        relativeTo: date
      )
    case .waitingForProxy:
      self.init(
        title: "等待 Mihomo 代理",
        message: "连接 Mihomo 并取得本地代理端口后才会查询，不会绕过代理直连。",
        compactSummary: Self.compactSummary(
          latestQuota: item.latestQuota,
          relativeTo: date,
          action: "等待 Mihomo 代理"
        ),
        symbolName: "link.badge.plus",
        tone: .waiting,
        overridesForecast: true
      )
    case .scheduled(let queryAt):
      let nextQuery = SubscriptionQuotaFormatter.upcomingDate(queryAt, relativeTo: date)
      let compactSummary: String
      if let latestQuota = item.latestQuota {
        let lastUpdate = SubscriptionQuotaFormatter.updatedAt(
          latestQuota.effectiveAt,
          relativeTo: date
        )
        compactSummary = "\(lastUpdate)更新 · \(nextQuery)再次查询"
      } else {
        compactSummary = "等待首次查询 · \(nextQuery)查询"
      }
      self.init(
        title: item.latestQuota == nil ? "等待首次查询" : "等待下次查询",
        message: compactSummary,
        compactSummary: compactSummary,
        symbolName: "clock",
        tone: .neutral
      )
    case .querying:
      self.init(
        title: "正在查询机场配额",
        message: "请求通过 Mihomo 本地代理发出。",
        compactSummary: Self.compactSummary(
          latestQuota: item.latestQuota,
          relativeTo: date,
          action: "正在查询"
        ),
        symbolName: "arrow.triangle.2.circlepath",
        tone: .waiting
      )
    case .available:
      self.init(
        title: "配额已更新",
        message: item.latestQuota.map {
          "\(SubscriptionQuotaFormatter.updatedAt($0.effectiveAt, relativeTo: date))更新"
        } ?? "本次查询已完成。",
        compactSummary: Self.compactSummary(
          latestQuota: item.latestQuota,
          relativeTo: date,
          action: nil,
          missingQuotaSummary: "配额已更新"
        ),
        symbolName: "checkmark.circle.fill",
        tone: .positive
      )
    case .failed(let message, let retryAt, _):
      let retrySummary =
        retryAt.map {
          "\(SubscriptionQuotaFormatter.upcomingDate($0, relativeTo: date))自动重试"
        } ?? "等待常规查询"
      self.init(
        title: "本次查询失败",
        message: Self.failureMessage(message, retryAt: retryAt, relativeTo: date),
        compactSummary: Self.compactSummary(
          latestQuota: item.latestQuota,
          relativeTo: date,
          action: retrySummary
        ),
        symbolName: "exclamationmark.triangle.fill",
        tone: .warning,
        overridesForecast: true
      )
    case .storageUnavailable(let message):
      self.init(
        title: "配额账本不可用",
        message: message,
        compactSummary: Self.compactSummary(
          latestQuota: item.latestQuota,
          relativeTo: date,
          action: "账本不可用"
        ),
        symbolName: "externaldrive.badge.exclamationmark",
        tone: .negative,
        overridesForecast: true
      )
    }
  }

  static func failureMessage(
    _ message: String,
    retryAt: Date?,
    relativeTo date: Date
  ) -> String {
    let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
    let failureSentence: String
    if let lastCharacter = trimmedMessage.last,
      "。！？".contains(lastCharacter)
    {
      failureSentence = trimmedMessage
    } else if trimmedMessage.isEmpty {
      failureSentence = "机场配额查询失败。"
    } else {
      failureSentence = "\(trimmedMessage)。"
    }
    let retrySentence =
      retryAt.map {
        "\(SubscriptionQuotaFormatter.upcomingDate($0, relativeTo: date))自动重试。"
      } ?? "等待下一个常规查询周期。"
    return "\(failureSentence)\(retrySentence)"
  }

  private static func unavailableProfile(
    _ availability: ClashProfileAvailability,
    latestQuota: SubscriptionQuotaSnapshot?,
    relativeTo date: Date
  ) -> ProfileQuotaStatusPresentation {
    switch availability {
    case .available:
      ProfileQuotaStatusPresentation(
        title: "订阅暂不可查询",
        message: "请重新读取 Profile 目录后再试。",
        compactSummary: compactSummary(
          latestQuota: latestQuota,
          relativeTo: date,
          action: "订阅暂不可查询"
        ),
        symbolName: "exclamationmark.triangle.fill",
        tone: .warning,
        overridesForecast: true
      )
    case .unsupportedURL:
      ProfileQuotaStatusPresentation(
        title: "订阅地址不受支持",
        message: "指定 Profile 模式只通过 HTTPS 查询。",
        compactSummary: compactSummary(
          latestQuota: latestQuota,
          relativeTo: date,
          action: "订阅地址不受支持"
        ),
        symbolName: "lock.slash",
        tone: .warning,
        overridesForecast: true
      )
    case .missing:
      ProfileQuotaStatusPresentation(
        title: "Profile 已不在目录中",
        message: "原 UID 和历史仍保留；恢复原 Profile 后可继续查询。",
        compactSummary: compactSummary(
          latestQuota: latestQuota,
          relativeTo: date,
          action: "Profile 已不在目录中"
        ),
        symbolName: "doc.questionmark",
        tone: .warning,
        overridesForecast: true
      )
    }
  }

  private static func compactSummary(
    latestQuota: SubscriptionQuotaSnapshot?,
    relativeTo date: Date,
    action: String?,
    missingQuotaSummary: String? = nil
  ) -> String {
    guard let latestQuota else {
      return missingQuotaSummary ?? action ?? "等待有效配额"
    }
    let updatedAt = SubscriptionQuotaFormatter.updatedAt(
      latestQuota.effectiveAt,
      relativeTo: date
    )
    guard let action else {
      return "\(updatedAt)更新"
    }
    return "\(updatedAt)更新 · \(action)"
  }
}
