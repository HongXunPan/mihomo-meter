import AppKit
import SwiftUI

enum StatusMenuLayout {
  static let contentWidth: CGFloat = 400
  static let configuredPrimaryContentSize = NSSize(width: contentWidth, height: 166)
  static let unconfiguredPrimaryContentSize = NSSize(width: contentWidth, height: 560)
  static let summaryContentSize = NSSize(width: contentWidth, height: 360)
  static let connectionSubmenuSize = NSSize(width: 360, height: 214)
  static let classificationSubmenuSize = NSSize(width: 360, height: 176)
  static let routingSubmenuSize = NSSize(width: 360, height: 278)
}

@MainActor
final class StatusMenuPresentationState: ObservableObject {
  @Published private(set) var presentationID = UUID()

  func prepareForPresentation() {
    presentationID = UUID()
  }
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
        ScrollView {
          FirstConnectionGuideView(showControllerSettings: showControllerSettings)
            .padding(16)
        }
      }
    }
    .frame(
      width: StatusMenuLayout.contentWidth,
      height: primaryContentHeight
    )
  }

  private var primaryContentHeight: CGFloat {
    monitor.hasValidatedControllerConfiguration
      ? StatusMenuLayout.configuredPrimaryContentSize.height
      : StatusMenuLayout.unconfiguredPrimaryContentSize.height
  }
}

struct StatusMenuSummaryContentView: View {
  @ObservedObject var presentationState: StatusMenuPresentationState
  @ObservedObject var monitor: TrafficMonitor
  @ObservedObject var statisticsController: TrafficStatisticsController
  @ObservedObject var quotaController: RuntimeQuotaTrackingController
  @ObservedObject var profileQuotaController: ProfileQuotaTrackingController

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          TrafficStatisticsSummaryView(
            controller: statisticsController,
            isMonitoringAvailable: allowsTrafficStatistics
          )

          sectionDivider

          SubscriptionQuotaSummaryView(
            controller: quotaController,
            profileQuotaController: profileQuotaController
          )
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
    .frame(
      width: StatusMenuLayout.summaryContentSize.width,
      height: StatusMenuLayout.summaryContentSize.height
    )
    .disclosureGroupStyle(StatusMenuDisclosureGroupStyle())
  }

  private var sectionDivider: some View {
    Divider()
      .padding(.vertical, 8)
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

private enum StatusMenuScrollAnchor {
  static let top = "status-menu-top"
}
