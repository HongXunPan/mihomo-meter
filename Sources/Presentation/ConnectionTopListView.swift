import SwiftUI

struct ProxyConnectionTopListView: View {
  let connections: [LiveTrafficConnection]
  @Binding var isExpanded: Bool

  var body: some View {
    ConnectionTopListView(
      connections: connections,
      isExpanded: $isExpanded,
      title: "活动 Proxy Top 5",
      emptyDescription: "暂无正在传输的 Proxy 连接。",
      helpText: "仅显示当前速率大于零的 Proxy 连接，按上下行总速率排序",
      accessibilityHintText: "显示当前传输中的 Proxy 连接"
    )
  }
}

struct DirectConnectionTopListView: View {
  let connections: [LiveTrafficConnection]
  @Binding var isExpanded: Bool

  var body: some View {
    ConnectionTopListView(
      connections: connections,
      isExpanded: $isExpanded,
      title: "活动直连 Top 5",
      emptyDescription: "暂无正在传输的 DIRECT 连接。",
      helpText: "仅显示当前速率大于零的 DIRECT 连接，按上下行总速率排序",
      accessibilityHintText: "显示当前传输中的 DIRECT 连接"
    )
  }
}

private struct ConnectionTopListView: View {
  let connections: [LiveTrafficConnection]
  @Binding var isExpanded: Bool
  let title: String
  let emptyDescription: String
  let helpText: String
  let accessibilityHintText: String

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
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
      .padding(.top, 8)
      .padding(.leading, 14)
    } label: {
      HStack(spacing: 8) {
        Text(title)
          .font(.subheadline.weight(.semibold))
          .fixedSize(horizontal: true, vertical: false)

        Spacer()

        Text(activeConnectionSummary)
          .font(.caption)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
    }
    .help(helpText)
    .accessibilityValue(isExpanded ? "已展开" : "已折叠")
    .accessibilityHint(accessibilityHintText)
  }

  private var slots: [LiveTrafficConnection?] {
    ConnectionAnalyticsPresentation.topConnectionSlots(from: connections)
  }

  private var activeConnectionCount: Int {
    ConnectionAnalyticsPresentation.activeConnectionCount(from: connections)
  }

  private var activeConnectionSummary: String {
    ConnectionAnalyticsPresentation.activeConnectionSummary(from: connections)
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
