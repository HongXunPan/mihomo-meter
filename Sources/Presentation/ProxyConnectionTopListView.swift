import SwiftUI

struct ProxyConnectionTopListView: View {
  let connections: [LiveProxyConnection]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("活动连接 Top 5")
          .font(.caption.weight(.semibold))
        Spacer()
        Text("按当前总速率")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if topConnections.isEmpty {
        Text("暂无正在传输的 Proxy 连接。")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
      } else {
        VStack(spacing: 7) {
          ForEach(topConnections) { connection in
            row(connection)
          }
        }
      }
    }
  }

  private var topConnections: [LiveProxyConnection] {
    ConnectionAnalyticsPresentation.topConnections(from: connections)
  }

  private func row(_ connection: LiveProxyConnection) -> some View {
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

  private func metric(symbol: String, value: UInt64, color: Color) -> some View {
    Label(TrafficRateFormatter.compactString(from: value), systemImage: symbol)
      .font(.caption2.monospacedDigit())
      .foregroundStyle(color)
  }
}
