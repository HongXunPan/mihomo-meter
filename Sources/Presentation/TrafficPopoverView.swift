import AppKit
import SwiftUI

enum TrafficPopoverLayout {
  static let contentSize = NSSize(width: 380, height: 560)
}

struct TrafficPopoverView: View {
  @ObservedObject var monitor: TrafficMonitor
  @State private var showsDiagnostics = false
  @State private var showsControllerConfiguration = false
  @State private var synchronizedConnectionState: MonitorConnectionState?

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 16)
        .padding(.vertical, 14)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if prioritizesControllerConfiguration {
            controllerConfiguration
            trafficOverview
          } else {
            trafficOverview
            controllerConfiguration
          }
        }
        .padding(16)
      }

      footer
    }
    .frame(
      width: TrafficPopoverLayout.contentSize.width,
      height: TrafficPopoverLayout.contentSize.height
    )
    .onReceive(monitor.$connectionState) { state in
      synchronizeControllerVisibility(for: state)
    }
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
      showsDiagnostics: $showsDiagnostics
    )
  }

  private var controllerConfiguration: some View {
    ControllerConfigurationView(
      monitor: monitor,
      isExpanded: $showsControllerConfiguration
    )
  }

  private var footer: some View {
    VStack(spacing: 0) {
      Divider()

      HStack {
        Text("只读监控，不修改 Mihomo 或系统代理。")
          .font(.caption2)
          .foregroundStyle(.secondary)

        Spacer()

        Button("退出") {
          NSApplication.shared.terminate(nil)
        }
        .controlSize(.small)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
    }
  }

  private var prioritizesControllerConfiguration: Bool {
    switch monitor.connectionState {
    case .disconnected, .connecting, .authenticationFailed, .unsupported:
      true
    case .connected, .stale, .reconnecting:
      false
    }
  }

  private var statusDescription: String {
    if monitor.connectionState == .connected {
      return "正在监控 Proxy 实时流量。"
    }
    return monitor.message
  }

  private var allowsImmediateReconnect: Bool {
    monitor.connectionState == .stale || monitor.connectionState == .reconnecting
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

  private func synchronizeControllerVisibility(
    for state: MonitorConnectionState
  ) {
    guard synchronizedConnectionState != state else {
      return
    }
    synchronizedConnectionState = state

    switch state {
    case .disconnected, .authenticationFailed, .unsupported:
      showsControllerConfiguration = true
    case .connecting, .connected, .stale, .reconnecting:
      break
    }
  }
}
