import SwiftUI

struct TrafficOverviewView: View {
  @ObservedObject var monitor: TrafficMonitor
  @Binding var showsRuntimeDetails: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      proxyRateSection
      TrafficClassificationView(monitor: monitor)
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
          value: monitor.rates.proxy.downloadBytesPerSecond
        )
        primaryMetric(
          title: "上传",
          symbol: "arrow.up",
          value: monitor.rates.proxy.uploadBytesPerSecond
        )
      }
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
}
