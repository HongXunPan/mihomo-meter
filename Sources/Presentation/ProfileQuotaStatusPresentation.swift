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
      .secondary
    case .positive:
      .green
    case .waiting:
      .cyan
    case .warning:
      .orange
    case .negative:
      .red
    }
  }
}

struct ProfileQuotaStatusPresentation {
  let title: String
  let message: String
  let symbolName: String
  let tone: ProfileQuotaStatusTone

  private init(
    title: String,
    message: String,
    symbolName: String,
    tone: ProfileQuotaStatusTone
  ) {
    self.title = title
    self.message = message
    self.symbolName = symbolName
    self.tone = tone
  }

  init(item: ProfileQuotaTrackingItem, relativeTo date: Date = Date()) {
    switch item.queryStatus {
    case .unavailableProfile:
      self = Self.unavailableProfile(item.availability)
    case .waitingForProxy:
      self.init(
        title: "等待 Mihomo 代理",
        message: "连接 Mihomo 并取得本地代理端口后才会查询，不会绕过代理直连。",
        symbolName: "link.badge.plus",
        tone: .waiting
      )
    case .scheduled(let queryAt):
      self.init(
        title: item.latestQuota == nil ? "等待首次查询" : "已安排下次查询",
        message: "\(SubscriptionQuotaFormatter.relativeDate(queryAt, relativeTo: date))查询",
        symbolName: "clock",
        tone: .neutral
      )
    case .querying:
      self.init(
        title: "正在查询机场配额",
        message: "请求通过 Mihomo 本地代理发出。",
        symbolName: "arrow.triangle.2.circlepath",
        tone: .waiting
      )
    case .available:
      self.init(
        title: "配额已更新",
        message: item.latestQuota.map {
          "更新于 \(SubscriptionQuotaFormatter.updatedAt($0.effectiveAt))"
        } ?? "本次查询已完成。",
        symbolName: "checkmark.circle.fill",
        tone: .positive
      )
    case .failed(let message, let retryAt):
      let retryMessage =
        retryAt.map {
          "；\(SubscriptionQuotaFormatter.relativeDate($0, relativeTo: date))自动重试"
        } ?? "；等待下一个常规查询周期"
      self.init(
        title: "本次查询失败",
        message: "\(message)\(retryMessage)",
        symbolName: "exclamationmark.triangle.fill",
        tone: .warning
      )
    case .storageUnavailable(let message):
      self.init(
        title: "配额账本不可用",
        message: message,
        symbolName: "externaldrive.badge.exclamationmark",
        tone: .negative
      )
    }
  }

  private static func unavailableProfile(
    _ availability: ClashProfileAvailability
  ) -> ProfileQuotaStatusPresentation {
    switch availability {
    case .available:
      ProfileQuotaStatusPresentation(
        title: "订阅暂不可查询",
        message: "请重新读取 Profile 目录后再试。",
        symbolName: "exclamationmark.triangle.fill",
        tone: .warning
      )
    case .unsupportedURL:
      ProfileQuotaStatusPresentation(
        title: "订阅地址不受支持",
        message: "指定 Profile 模式只通过 HTTPS 查询。",
        symbolName: "lock.slash",
        tone: .warning
      )
    case .missing:
      ProfileQuotaStatusPresentation(
        title: "Profile 已不在目录中",
        message: "原 UID 和历史仍保留；恢复原 Profile 后可继续查询。",
        symbolName: "doc.questionmark",
        tone: .warning
      )
    }
  }
}
