import SwiftUI

struct ControllerSettingsView: View {
  @ObservedObject var monitor: TrafficMonitor

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 20)
        .padding(.vertical, 16)

      Divider()

      Form {
        Section("Controller") {
          TextField("服务地址", text: $monitor.address, prompt: Text("127.0.0.1:9090"))
          SecureField("访问密钥（Secret）", text: $monitor.secret)
        }

        Section {
          HStack {
            connectAction

            if monitor.connectionState != .disconnected {
              Button("断开") {
                monitor.disconnect()
              }
            }

            Spacer()
            AppHelpLinksMenu()
          }

          Text("仅连接本机回环地址；验证成功后安全保存至 macOS 登录钥匙串。")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
    }
    .frame(minWidth: 480, minHeight: 320)
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Mihomo 连接")
          .font(.title2.weight(.semibold))
        Text(monitor.message)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      Spacer()

      Label(
        monitor.connectionState.title,
        systemImage: monitor.connectionState.symbolName
      )
      .font(.callout.weight(.medium))
      .foregroundStyle(stateColor)
    }
  }

  @ViewBuilder
  private var connectAction: some View {
    if usesProminentConnectAction {
      connectButton
        .buttonStyle(.borderedProminent)
    } else {
      connectButton
    }
  }

  private var connectButton: some View {
    Button(connectButtonTitle) {
      monitor.connect()
    }
    .keyboardShortcut(.defaultAction)
    .disabled(isConnectDisabled)
  }

  private var connectButtonTitle: String {
    switch monitor.connectionState {
    case .connecting:
      "正在连接…"
    case .connected, .stale, .reconnecting:
      "重新连接"
    case .disconnected, .authenticationFailed, .unsupported:
      "连接"
    }
  }

  private var isConnectDisabled: Bool {
    monitor.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || monitor.connectionState == .connecting
  }

  private var usesProminentConnectAction: Bool {
    switch monitor.connectionState {
    case .disconnected, .authenticationFailed, .unsupported:
      true
    case .connecting, .connected, .stale, .reconnecting:
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
