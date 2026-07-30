import SwiftUI

struct ProxyConnectionTopListView: View {
  @ObservedObject var monitor: TrafficMonitor

  var body: some View {
    ConnectionTopListView(
      connections: monitor.liveProxyConnections,
      emptyDescription: "暂无正在传输的 Proxy 连接。",
      accessibilityLabel: "当前传输中的 Proxy 连接"
    )
  }
}

struct DirectConnectionTopListView: View {
  @ObservedObject var monitor: TrafficMonitor

  var body: some View {
    ConnectionTopListView(
      connections: monitor.liveDirectConnections,
      emptyDescription: "暂无正在传输的 DIRECT 连接。",
      accessibilityLabel: "当前传输中的 DIRECT 连接"
    )
  }
}

private struct ConnectionTopListView: View {
  let connections: [LiveTrafficConnection]
  let emptyDescription: String
  let accessibilityLabel: String

  var body: some View {
    ZStack {
      VStack(spacing: 7) {
        ForEach(slots.indices, id: \.self) { index in
          if let connection = slots[index] {
            row(connection)
          } else {
            rowPlaceholder
          }
        }
      }

      if activeConnectionCount == 0 {
        Text(emptyDescription)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(accessibilityLabel)
  }

  private var slots: [LiveTrafficConnection?] {
    ConnectionAnalyticsPresentation.topConnectionSlots(from: connections)
  }

  private var activeConnectionCount: Int {
    ConnectionAnalyticsPresentation.activeConnectionCount(from: connections)
  }

  private func row(_ connection: LiveTrafficConnection) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 6) {
        Text(connection.metadata.hostname ?? ConnectionAttributionLabel.unknownHostname)
          .font(.caption.weight(.medium))
          .lineLimit(1)
          .truncationMode(.middle)
        Text("·")
          .foregroundStyle(.tertiary)
        Text(connection.metadata.applicationName ?? ConnectionAttributionLabel.unknownApplication)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      HStack(spacing: 10) {
        metric(
          symbol: "arrow.down",
          value: connection.rate.downloadBytesPerSecond,
          color: MihomoColorToken.trafficDownload
        )
        metric(
          symbol: "arrow.up",
          value: connection.rate.uploadBytesPerSecond,
          color: MihomoColorToken.trafficUpload
        )
        Spacer()
        Text("累计 \(TrafficStatisticsFormatter.bytes(connection.cumulativeBytes.total))")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 2)
  }

  private var rowPlaceholder: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 6) {
        Text("连接主机名")
          .font(.caption.weight(.medium))
        Text("·")
        Text("应用名称")
          .font(.caption)
      }

      HStack(spacing: 10) {
        Text("下载速率")
          .font(.caption2)
        Text("上传速率")
          .font(.caption2)
        Spacer()
        Text("累计流量")
          .font(.caption2)
      }
    }
    .padding(.vertical, 2)
    .hidden()
    .accessibilityHidden(true)
  }

  private func metric(symbol: String, value: UInt64, color: Color) -> some View {
    Label(TrafficRateFormatter.compactString(from: value), systemImage: symbol)
      .font(.caption2.monospacedDigit())
      .foregroundStyle(color)
  }
}
