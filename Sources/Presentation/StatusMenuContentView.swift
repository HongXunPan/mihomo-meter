import AppKit
import SwiftUI

enum StatusMenuLayout {
  static let contentSize = NSSize(width: 400, height: 620)
}

struct StatusMenuContentView: View {
  @ObservedObject var monitor: TrafficMonitor
  @ObservedObject var statisticsController: TrafficStatisticsController
  @ObservedObject var quotaController: RuntimeQuotaTrackingController
  @ObservedObject var profileQuotaController: ProfileQuotaTrackingController
  @ObservedObject var updateModel: AppUpdateModel
  let checkForUpdates: () -> Void
  let startStatistics: () -> Void
  let showAllStatistics: () -> Void
  let showQuotaStatistics: () -> Void

  @State private var showsRuntimeDetails = false

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 16)
        .padding(.vertical, 14)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          trafficOverview
          sectionDivider
          trafficStatistics
          sectionDivider
          subscriptionQuota
        }
        .padding(16)
      }

      footer
    }
    .frame(
      width: StatusMenuLayout.contentSize.width,
      height: StatusMenuLayout.contentSize.height
    )
    .disclosureGroupStyle(StatusMenuDisclosureGroupStyle())
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Mihomo Meter")
          .font(.title3.weight(.semibold))

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
          .buttonStyle(.bordered)
          .controlSize(.small)
          .accessibilityHint("取消当前等待并立即重新连接 Mihomo 服务")
        }
      }
    }
  }

  private var trafficOverview: some View {
    TrafficOverviewView(
      monitor: monitor,
      showsRuntimeDetails: $showsRuntimeDetails
    )
  }

  private var trafficStatistics: some View {
    TrafficStatisticsSummaryView(
      controller: statisticsController,
      isMonitoringAvailable: allowsTrafficStatistics,
      startStatistics: startStatistics,
      showAllStatistics: showAllStatistics
    )
  }

  private var subscriptionQuota: some View {
    SubscriptionQuotaSummaryView(
      controller: quotaController,
      profileQuotaController: profileQuotaController,
      showAllStatistics: showQuotaStatistics
    )
  }

  private var sectionDivider: some View {
    Divider()
      .padding(.vertical, 8)
  }

  private var footer: some View {
    VStack(spacing: 0) {
      Divider()

      VStack(alignment: .leading, spacing: 3) {
        Text("只读监控，不修改 Mihomo 或系统代理。")
          .font(.caption2)
          .foregroundStyle(.secondary)

        AppUpdateView(
          model: updateModel,
          checkForUpdates: checkForUpdates
        )
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
    }
  }

  private var statusDescription: String {
    if monitor.connectionState == .connected {
      guard monitor.lastObservedAt != nil else {
        return "正在监控 Proxy 实时流量。"
      }
      return "正在监控 Proxy 实时流量 · 刚刚更新"
    }
    return monitor.message
  }

  private var allowsImmediateReconnect: Bool {
    monitor.connectionState == .stale || monitor.connectionState == .reconnecting
  }

  private var allowsTrafficStatistics: Bool {
    switch monitor.connectionState {
    case .connected, .stale, .reconnecting:
      true
    case .disconnected, .connecting, .authenticationFailed, .unsupported:
      false
    }
  }

  private var stateColor: Color {
    switch monitor.connectionState {
    case .connected:
      .green
    case .connecting, .reconnecting:
      .orange
    case .stale, .authenticationFailed, .unsupported:
      .red
    case .disconnected:
      .secondary
    }
  }

}
