import SwiftUI

struct LiveConnectionAnalyticsView: View {
  @ObservedObject var monitor: TrafficMonitor

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      coverageSummary

      if sortedConnections.isEmpty {
        ContentUnavailableView(
          "暂无 Proxy 连接",
          systemImage: "point.3.connected.trianglepath.dotted",
          description: Text("连接出现后会在这里实时展示；消失后立即移除，不保留明细。")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        Table(sortedConnections) {
          TableColumn("主机名") { connection in
            Text(connection.metadata.hostname ?? ConnectionAttributionLabel.unknownHostname)
              .lineLimit(1)
              .truncationMode(.middle)
          }
          TableColumn("应用") { connection in
            Text(
              connection.metadata.applicationName
                ?? ConnectionAttributionLabel.unknownApplication
            )
            .lineLimit(1)
          }
          TableColumn("下载") { connection in
            Text(TrafficRateFormatter.string(from: connection.rate.downloadBytesPerSecond))
              .monospacedDigit()
              .foregroundStyle(MihomoColorToken.trafficDownload)
          }
          .width(min: 90, ideal: 110)
          TableColumn("上传") { connection in
            Text(TrafficRateFormatter.string(from: connection.rate.uploadBytesPerSecond))
              .monospacedDigit()
              .foregroundStyle(MihomoColorToken.trafficUpload)
          }
          .width(min: 90, ideal: 110)
          TableColumn("累计") { connection in
            Text(TrafficStatisticsFormatter.bytes(connection.cumulativeBytes.total))
              .monospacedDigit()
          }
          .width(min: 80, ideal: 100)
          TableColumn("时长") { connection in
            Text(duration(connection))
              .monospacedDigit()
          }
          .width(min: 72, ideal: 88)
        }
      }
    }
  }

  private var sortedConnections: [LiveProxyConnection] {
    monitor.liveProxyConnections.sorted {
      if $0.totalBytesPerSecond != $1.totalBytesPerSecond {
        return $0.totalBytesPerSecond > $1.totalBytesPerSecond
      }
      return ($0.metadata.hostname ?? "") < ($1.metadata.hostname ?? "")
    }
  }

  private var coverageSummary: some View {
    HStack(spacing: 12) {
      coverageMetric("主机名", rate: monitor.attributionCoverage.hostnameRate)
      coverageMetric("应用", rate: monitor.attributionCoverage.applicationRate)
      coverageMetric("两者同时", rate: monitor.attributionCoverage.fullyIdentifiedRate)
      Spacer()
      Text("本次连接会话 · 不保存明细")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func coverageMetric(_ title: String, rate: Double?) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(TrafficRateFormatter.percentage(from: rate))
        .font(.callout.weight(.semibold))
        .monospacedDigit()
    }
  }

  private func duration(_ connection: LiveProxyConnection) -> String {
    guard let startedAt = connection.startedAt else {
      return "—"
    }
    return TrafficStatisticsFormatter.duration(from: startedAt, to: Date())
  }
}
