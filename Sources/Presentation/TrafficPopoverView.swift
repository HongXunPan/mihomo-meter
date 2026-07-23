import AppKit
import SwiftUI

struct TrafficPopoverView: View {
  @ObservedObject var monitor: TrafficMonitor
  @State private var showsDiagnostics = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        controllerForm
        proxyRateCard
        categorySection
        qualitySection
        footer
      }
      .padding(16)
    }
    .frame(width: 380, height: 560)
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

      Text(monitor.message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var controllerForm: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Controller")
        .font(.headline)

      TextField("127.0.0.1:9090", text: $monitor.address)
        .textFieldStyle(.roundedBorder)

      SecureField("Secret（无鉴权时可留空）", text: $monitor.secret)
        .textFieldStyle(.roundedBorder)

      HStack {
        Button(connectButtonTitle) {
          monitor.connect()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(trimmedAddress.isEmpty)

        if monitor.connectionState != .disconnected {
          Button("停止") {
            monitor.disconnect()
          }
        }

        Spacer()

        if let version = monitor.mihomoVersion {
          Text("Mihomo \(version)")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }

      Text("仅连接本机回环地址；验证成功后，Secret 保存到本应用的 macOS Keychain。")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var proxyRateCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Proxy 实时速度", systemImage: "network")
          .font(.headline)
        Spacer()
        Text("2 秒平滑")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 12) {
        primaryMetric(
          title: "下载",
          symbol: "arrow.down",
          value: monitor.rates.proxy.downloadBytesPerSecond
        )
        primaryMetric(
          title: "上传",
          symbol: "arrow.up",
          value: monitor.rates.proxy.uploadBytesPerSecond
        )
      }
    }
    .padding(12)
    .background(Color.accentColor.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  private var categorySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("分类速度")
        .font(.headline)

      categoryRow(title: "DIRECT", rate: monitor.rates.direct)
      categoryRow(title: "REJECT", rate: monitor.rates.reject)
      categoryRow(title: "未知", rate: monitor.rates.unknown)
    }
  }

  private var qualitySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("分类可信度")
        Spacer()
        Text(TrafficRateFormatter.percentage(from: monitor.coverage))
          .monospacedDigit()
      }

      if TrafficCoveragePolicy.quality(for: monitor.coverage) == .low {
        Label(
          "覆盖率低于 95%，当前结果不适合精确判断。",
          systemImage: "exclamationmark.triangle.fill"
        )
        .font(.caption)
        .foregroundStyle(.orange)
      }

      if monitor.activeProxyLeaves.isEmpty {
        Text("当前没有可确认的 Proxy 叶子出口")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Text("Proxy 叶子：\(monitor.activeProxyLeaves.joined(separator: "、"))")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      DisclosureGroup("诊断：原始 1 秒 Proxy 速度", isExpanded: $showsDiagnostics) {
        categoryRow(title: "原始值", rate: monitor.rawRates.proxy)
          .padding(.top, 6)
      }
      .font(.caption)
    }
  }

  private var footer: some View {
    VStack(spacing: 10) {
      Divider()

      HStack {
        Text("只读监控，不修改 Mihomo 或系统代理。")
          .font(.caption2)
          .foregroundStyle(.secondary)

        Spacer()

        Button("退出") {
          NSApplication.shared.terminate(nil)
        }
      }
    }
  }

  private var trimmedAddress: String {
    monitor.address.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var connectButtonTitle: String {
    switch monitor.connectionState {
    case .connected, .stale, .reconnecting:
      "重新连接"
    default:
      "连接"
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

  private func primaryMetric(
    title: String,
    symbol: String,
    value: UInt64
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Label(title, systemImage: symbol)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(TrafficRateFormatter.string(from: value))
        .font(.system(.title3, design: .rounded).weight(.semibold))
        .monospacedDigit()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func categoryRow(title: String, rate: TrafficRate) -> some View {
    HStack {
      Text(title)
      Spacer()
      Text("↓ \(TrafficRateFormatter.string(from: rate.downloadBytesPerSecond))")
        .monospacedDigit()
      Text("↑ \(TrafficRateFormatter.string(from: rate.uploadBytesPerSecond))")
        .monospacedDigit()
    }
    .font(.caption)
  }
}
