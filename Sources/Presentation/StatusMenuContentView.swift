import SwiftUI

enum StatusMenuLayout {
  static let contentWidth: CGFloat = 400
  static let connectionSubmenuSize = CGSize(width: 360, height: 214)
  static let classificationSubmenuSize = CGSize(width: 360, height: 176)
  static let routingSubmenuSize = CGSize(width: 360, height: 278)
  static let quotaTrendSubmenuSize = CGSize(width: 380, height: 460)
}

struct StatusMenuPrimaryContentView: View {
  @ObservedObject var monitor: TrafficMonitor
  let showControllerSettings: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      StatusMenuHeaderView(monitor: monitor)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

      Divider()

      if monitor.hasValidatedControllerConfiguration {
        TrafficOverviewView(monitor: monitor)
          .padding(16)
      } else {
        FirstConnectionGuideView(showControllerSettings: showControllerSettings)
          .padding(16)
      }
    }
    .frame(width: StatusMenuLayout.contentWidth)
    .fixedSize(horizontal: false, vertical: true)
  }
}

struct StatusMenuTrafficSummaryContentView: View {
  @ObservedObject var monitor: TrafficMonitor
  @ObservedObject var controller: TrafficStatisticsController

  var body: some View {
    TrafficStatisticsSummaryView(
      controller: controller,
      isMonitoringAvailable: allowsTrafficStatistics
    )
    .padding(16)
    .frame(width: StatusMenuLayout.contentWidth)
    .fixedSize(horizontal: false, vertical: true)
  }

  private var allowsTrafficStatistics: Bool {
    switch monitor.connectionState {
    case .connected, .stale, .reconnecting:
      true
    case .disconnected, .connecting, .authenticationFailed, .unsupported:
      false
    }
  }
}

struct StatusMenuQuotaSummaryContentView: View {
  @ObservedObject var controller: RuntimeQuotaTrackingController
  @ObservedObject var profileQuotaController: ProfileQuotaTrackingController

  var body: some View {
    SubscriptionQuotaSummaryView(
      controller: controller,
      profileQuotaController: profileQuotaController
    )
    .padding(16)
    .frame(width: StatusMenuLayout.contentWidth)
    .fixedSize(horizontal: false, vertical: true)
  }
}

private struct StatusMenuHeaderView: View {
  @ObservedObject var monitor: TrafficMonitor

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text("Mihomo Meter")
          .font(.headline)

        Spacer()

        Label(
          monitor.connectionState.title,
          systemImage: monitor.connectionState.symbolName
        )
        .font(.caption.weight(.medium))
        .foregroundStyle(stateColor)
      }

      HStack(spacing: 8) {
        Text(statusDescription)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.tail)
          .help(statusDescription)

        Spacer(minLength: 8)

        if allowsImmediateReconnect {
          Button("立即重连") {
            monitor.reconnectNow()
          }
          .buttonStyle(.borderless)
          .controlSize(.small)
          .accessibilityHint("取消当前等待并立即重新连接 Mihomo 服务")
        }
      }
    }
  }

  private var statusDescription: String {
    if monitor.connectionState == .connected {
      guard monitor.lastObservedAt != nil else {
        return "Proxy 监控 · 等待首份数据"
      }
      return "Proxy 监控 · 刚刚更新"
    }
    return monitor.message
  }

  private var allowsImmediateReconnect: Bool {
    monitor.connectionState == .stale || monitor.connectionState == .reconnecting
  }

  private var stateColor: Color {
    switch monitor.connectionState {
    case .connected:
      MihomoColorToken.statusSuccess
    case .connecting, .reconnecting:
      MihomoColorToken.brandPrimary
    case .stale:
      MihomoColorToken.statusWarning
    case .authenticationFailed, .unsupported:
      MihomoColorToken.statusDanger
    case .disconnected:
      MihomoColorToken.statusNeutral
    }
  }
}
