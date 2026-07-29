import AppKit
import SwiftUI

enum StatusMenuLayout {
  static let contentSize = NSSize(width: 400, height: 560)
}

@MainActor
final class StatusMenuPresentationState: ObservableObject {
  @Published private(set) var presentationID = UUID()

  func prepareForPresentation() {
    presentationID = UUID()
  }
}

struct StatusMenuContentView: View {
  @ObservedObject var presentationState: StatusMenuPresentationState
  @ObservedObject var monitor: TrafficMonitor
  @ObservedObject var statisticsController: TrafficStatisticsController
  @ObservedObject var quotaController: RuntimeQuotaTrackingController
  @ObservedObject var profileQuotaController: ProfileQuotaTrackingController
  let showAllStatistics: () -> Void
  let showQuotaStatistics: () -> Void

  @State private var showsRuntimeDetails = false

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

      Divider()

      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            trafficOverview
            sectionDivider
            trafficStatistics
            sectionDivider
            subscriptionQuota
          }
          .id(StatusMenuScrollAnchor.top)
          .padding(16)
        }
        .onAppear {
          proxy.scrollTo(StatusMenuScrollAnchor.top, anchor: .top)
        }
        .onChange(of: presentationState.presentationID) { _, _ in
          Task { @MainActor in
            proxy.scrollTo(StatusMenuScrollAnchor.top, anchor: .top)
          }
        }
      }
    }
    .frame(
      width: StatusMenuLayout.contentSize.width,
      height: StatusMenuLayout.contentSize.height
    )
    .disclosureGroupStyle(StatusMenuDisclosureGroupStyle())
  }

  private var header: some View {
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

private enum StatusMenuScrollAnchor {
  static let top = "status-menu-top"
}
