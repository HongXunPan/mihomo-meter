import SwiftUI

struct ControllerConfigurationView: View {
  @ObservedObject var monitor: TrafficMonitor
  @Binding var isExpanded: Bool

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      controllerForm
        .padding(.top, 10)
    } label: {
      HStack(spacing: 8) {
        Text("Mihomo 连接")
          .font(.subheadline.weight(.semibold))
          .fixedSize(horizontal: true, vertical: false)

        Text(controllerSummary)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .help(controllerSummary)
      }
    }
  }

  private var controllerForm: some View {
    VStack(alignment: .leading, spacing: 10) {
      controllerField(title: "服务地址") {
        TextField("127.0.0.1:9090", text: $monitor.address)
          .textFieldStyle(.roundedBorder)
      }

      controllerField(title: "访问密钥（Secret）") {
        SecureField("无鉴权时可留空", text: $monitor.secret)
          .textFieldStyle(.roundedBorder)
      }

      HStack {
        connectAction

        if monitor.connectionState != .disconnected {
          Button("断开") {
            monitor.disconnect()
          }
          .buttonStyle(.bordered)
        }

        Spacer()

        AppHelpLinksMenu()
      }

      Text("仅连接本机回环地址；验证成功后安全保存至 macOS 钥匙串。")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  private var connectAction: some View {
    if usesProminentConnectAction {
      connectButton
        .buttonStyle(.borderedProminent)
    } else {
      connectButton
        .buttonStyle(.bordered)
    }
  }

  private var connectButton: some View {
    Button(connectButtonTitle) {
      monitor.connect()
    }
    .keyboardShortcut(.defaultAction)
    .disabled(isConnectDisabled)
  }

  private var controllerSummary: String {
    var components = [trimmedAddress.isEmpty ? "未配置" : trimmedAddress]
    if let version = monitor.mihomoVersion {
      components.append("v\(version)")
    }
    return components.joined(separator: " · ")
  }

  private var trimmedAddress: String {
    monitor.address.trimmingCharacters(in: .whitespacesAndNewlines)
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
    trimmedAddress.isEmpty || monitor.connectionState == .connecting
  }

  private var usesProminentConnectAction: Bool {
    switch monitor.connectionState {
    case .disconnected, .authenticationFailed, .unsupported:
      true
    case .connecting, .connected, .stale, .reconnecting:
      false
    }
  }

  private func controllerField<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      content()
    }
  }
}
