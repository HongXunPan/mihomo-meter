import AppKit
import Combine
import SwiftUI

struct ControllerSettingsView: View {
  @ObservedObject var monitor: TrafficMonitor
  @ObservedObject var updateModel: AppUpdateModel
  @ObservedObject var launchAtLoginController: LaunchAtLoginController
  @ObservedObject var systemNotificationController: SystemNotificationController
  @ObservedObject var diagnosticExportController: DiagnosticExportController
  @State private var isDiagnosticExportConfirmationPresented = false

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 20)
        .padding(.vertical, 16)

      Divider()

      Form {
        Section("连接信息") {
          Text("服务地址和访问密钥来自代理客户端的“外部控制器”，不是订阅链接、机场密码或节点密码。")
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)

          Link(destination: AppHelpLink.prepareMihomo.destination) {
            Label("不知道 Mihomo 是什么？查看零基础教程", systemImage: "book.closed")
          }

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

        Section("启动") {
          Toggle(
            "登录后启动 Mihomo Meter",
            isOn: Binding(
              get: { launchAtLoginController.isRequested },
              set: { launchAtLoginController.setEnabled($0) }
            )
          )

          Text(launchAtLoginController.statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)

          if launchAtLoginController.requiresApproval {
            Button("打开登录项设置") {
              launchAtLoginController.openSystemSettings()
            }
          }

          if let errorMessage = launchAtLoginController.errorMessage {
            Text(errorMessage)
              .font(.caption)
              .foregroundStyle(MihomoColorToken.statusDanger)
          }
        }

        Section("通知") {
          Toggle(
            "系统通知",
            isOn: Binding(
              get: { systemNotificationController.isEnabled },
              set: { systemNotificationController.setEnabled($0) }
            )
          )

          Toggle(
            "连接连续中断 10 分钟时提醒",
            isOn: Binding(
              get: { systemNotificationController.disconnectAlertsEnabled },
              set: { systemNotificationController.setDisconnectAlertsEnabled($0) }
            )
          )
          .disabled(!systemNotificationController.isEnabled)

          Text(systemNotificationController.statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)

          if let errorMessage = systemNotificationController.errorMessage {
            Text(errorMessage)
              .font(.caption)
              .foregroundStyle(MihomoColorToken.statusDanger)
          }
        }

        Section("诊断") {
          Text("导出应用与系统版本、当前连接状态，以及当前会话最多 200 条脱敏事件。")
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)

          Button("导出诊断信息…") {
            isDiagnosticExportConfirmationPresented = true
          }
          .disabled(diagnosticExportController.isExporting)

          if diagnosticExportController.isExporting {
            ProgressView("正在准备诊断信息…")
              .controlSize(.small)
          }

          if let statusMessage = diagnosticExportController.statusMessage {
            Text(statusMessage)
              .font(.caption)
              .foregroundStyle(MihomoColorToken.statusSuccess)
          }

          if let errorMessage = diagnosticExportController.errorMessage {
            Text(errorMessage)
              .font(.caption)
              .foregroundStyle(MihomoColorToken.statusDanger)
          }
        }
      }
      .formStyle(.grouped)

      Divider()

      HStack(spacing: 12) {
        Text("只读监控，不修改 Mihomo 或系统代理。")

        Spacer()

        Text("版本 \(updateModel.currentVersionText)")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
    }
    .frame(minWidth: 480, minHeight: 320)
    .onAppear {
      launchAtLoginController.refresh()
      systemNotificationController.refreshAuthorization()
    }
    .onReceive(
      NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
    ) { _ in
      launchAtLoginController.refresh()
      systemNotificationController.refreshAuthorization()
    }
    .confirmationDialog(
      "导出诊断信息？",
      isPresented: $isDiagnosticExportConfirmationPresented,
      titleVisibility: .visible
    ) {
      Button("选择保存位置") {
        diagnosticExportController.export(connectionState: monitor.connectionState)
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text(
        "包含版本、系统架构、固定连接状态与脱敏事件；不包含 Controller 地址或 Secret、订阅/Profile 标识、数据库、文件路径、真实连接元数据、原始错误或日志原文。文件不会自动上传。"
      )
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Mihomo Meter 设置")
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
