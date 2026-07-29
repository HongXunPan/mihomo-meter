import SwiftUI

struct RuntimeDetailsView: View {
  @ObservedObject var monitor: TrafficMonitor

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      rawProxyRateRow
      detailRow(
        title: "TUN Stack",
        value: monitor.runtimeConfiguration?.tun?.stack ?? "—"
      )
      detailRow(
        title: "自动路由",
        value: booleanSummary(
          monitor.runtimeConfiguration?.tun?.automaticallyRoutesTraffic
        )
      )
      detailRow(
        title: "IPv6",
        value: booleanSummary(monitor.runtimeConfiguration?.isIPv6Enabled)
      )
      detailRow(
        title: "局域网访问",
        value: booleanSummary(
          monitor.runtimeConfiguration?.allowsLAN,
          enabled: "允许",
          disabled: "禁止"
        )
      )
      detailRow(title: "Mixed Port", value: mixedPortSummary)
      detailRow(title: "Mihomo", value: monitor.mihomoVersion ?? "—")
    }
  }

  private var rawProxyRateSummary: String {
    guard monitor.connectionState == .connected else {
      return "—"
    }

    return [
      "↓ \(TrafficRateFormatter.string(from: monitor.rawRates.proxy.downloadBytesPerSecond))",
      "↑ \(TrafficRateFormatter.string(from: monitor.rawRates.proxy.uploadBytesPerSecond))",
    ].joined(separator: "  ")
  }

  private var rawProxyRateRow: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text("原始 1 秒 Proxy")
        .foregroundStyle(.secondary)

      Spacer(minLength: 8)

      if monitor.connectionState == .connected {
        HStack(spacing: 10) {
          Text(
            "↓ \(TrafficRateFormatter.string(from: monitor.rawRates.proxy.downloadBytesPerSecond))"
          )
          .foregroundStyle(MihomoColorToken.trafficDownload)
          Text(
            "↑ \(TrafficRateFormatter.string(from: monitor.rawRates.proxy.uploadBytesPerSecond))"
          )
          .foregroundStyle(MihomoColorToken.trafficUpload)
        }
        .monospacedDigit()
        .lineLimit(1)
        .help(rawProxyRateSummary)
      } else {
        Text("—")
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("原始 1 秒 Proxy，\(rawProxyRateSummary)")
  }

  private var mixedPortSummary: String {
    guard let mixedPort = monitor.runtimeConfiguration?.mixedPort else {
      return "—"
    }
    return mixedPort > 0 ? String(mixedPort) : "未启用"
  }

  private func booleanSummary(
    _ value: Bool?,
    enabled: String = "开启",
    disabled: String = "关闭"
  ) -> String {
    guard let value else {
      return "—"
    }
    return value ? enabled : disabled
  }

  private func detailRow(
    title: String,
    value: String
  ) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text(title)
        .foregroundStyle(.secondary)

      Spacer(minLength: 8)

      Text(value)
        .monospacedDigit()
        .lineLimit(1)
        .truncationMode(.middle)
        .help(value)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(title)，\(value)")
  }
}
