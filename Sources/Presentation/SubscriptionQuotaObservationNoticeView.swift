import SwiftUI

struct SubscriptionQuotaObservationNoticeView: View {
  @ObservedObject var controller: RuntimeQuotaTrackingController

  var body: some View {
    Label(message, systemImage: symbolName)
      .font(.caption)
      .foregroundStyle(color)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var message: String {
    if controller.snapshot.isPaused {
      return pauseMessage
    }

    switch controller.snapshot.observationStatus {
    case .loading:
      return "正在读取订阅额度账本…"
    case .controllerUnavailable:
      return "连接 Mihomo 后检查当前运行订阅。"
    case .checking:
      return "正在检查 Mihomo 当前运行配额…"
    case .available:
      return controller.snapshot.subscription == nil
        ? "发现唯一有效配额；确认后才会开始记录。"
        : "额度来自 Mihomo 当前运行信息，不等同于本机 Proxy 流量。"
    case .noCandidate:
      return "当前运行配置未暴露可用配额。轻量模式暂时无法记录；可授权 Profile 目录后启用主动查询。"
    case .multipleCandidates(let count):
      return "发现 \(count) 个有效配额，无法判断所属 Profile，已暂停记录。"
    case .failed(let message):
      return "本次读取失败：\(message)"
    case .unavailable(let message):
      return message
    }
  }

  private var pauseMessage: String {
    switch controller.snapshot.pauseReason {
    case .noCandidate:
      "有效配额消失，轻量追踪已暂停。"
    case .multipleCandidates:
      "出现多个有效配额，轻量追踪已暂停。"
    case .sourceChanged:
      "运行时 Provider 来源发生变化，请确认后再继续。"
    case .controllerChanged:
      "Mihomo 服务地址发生变化，请确认后再继续。"
    case .previousAmbiguity, .none:
      "此前出现归属歧义，轻量追踪保持暂停。"
    }
  }

  private var symbolName: String {
    switch controller.snapshot.observationStatus {
    case .available:
      controller.snapshot.isPaused ? "pause.circle.fill" : "checkmark.circle.fill"
    case .loading, .checking:
      "clock"
    case .controllerUnavailable:
      "link.badge.plus"
    case .noCandidate, .multipleCandidates, .failed, .unavailable:
      "exclamationmark.triangle.fill"
    }
  }

  private var color: Color {
    switch controller.snapshot.observationStatus {
    case .available:
      controller.snapshot.isPaused
        ? MihomoColorToken.statusWarning : MihomoColorToken.statusSuccess
    case .loading, .checking, .controllerUnavailable:
      MihomoColorToken.statusInfo
    case .noCandidate, .multipleCandidates, .failed:
      MihomoColorToken.statusWarning
    case .unavailable:
      MihomoColorToken.statusDanger
    }
  }
}
