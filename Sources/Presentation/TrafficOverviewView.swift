import SwiftUI

struct TrafficOverviewView: View {
  @ObservedObject var monitor: TrafficMonitor
  @Binding var showsRuntimeDetails: Bool
  @State private var showsActiveProxyConnections = true
  @State private var showsActiveDirectConnections = false
  @State private var showsClassificationDetails = false

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      proxyRateSection
      TrafficClassificationView(
        monitor: monitor,
        isExpanded: $showsClassificationDetails
      )
      RoutingStatusView(
        monitor: monitor,
        showsRuntimeDetails: $showsRuntimeDetails
      )
    }
  }

  private var proxyRateSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Proxy 实时速度", systemImage: "network")
          .font(.headline)
        Spacer()
        Text("2 秒平均")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 12) {
        primaryMetric(
          title: "下载",
          symbol: "arrow.down",
          value: monitor.rates.proxy.downloadBytesPerSecond,
          color: MihomoColorToken.trafficDownload
        )
        Divider()
          .frame(height: 40)
        primaryMetric(
          title: "上传",
          symbol: "arrow.up",
          value: monitor.rates.proxy.uploadBytesPerSecond,
          color: MihomoColorToken.trafficUpload
        )
      }

      Divider()

      ProxyConnectionTopListView(
        connections: monitor.liveProxyConnections,
        isExpanded: $showsActiveProxyConnections
      )

      Divider()

      DirectConnectionTopListView(
        connections: monitor.liveDirectConnections,
        isExpanded: $showsActiveDirectConnections
      )
    }
  }

  private func primaryMetric(
    title: String,
    symbol: String,
    value: UInt64,
    color: Color
  ) -> some View {
    VStack(alignment: .center, spacing: 4) {
      Label(title, systemImage: symbol)
        .font(.caption)
        .foregroundStyle(color)
      Text(TrafficRateFormatter.string(from: value))
        .font(.system(.title3, design: .rounded).weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .center)
  }
}
