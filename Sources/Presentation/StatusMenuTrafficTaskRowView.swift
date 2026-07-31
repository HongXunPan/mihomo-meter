import SwiftUI

struct StatusMenuTrafficTaskRowView: View {
  static let height: CGFloat = 68

  let interval: TrafficInterval?
  let now: Date
  let isStatisticsAvailable: Bool
  let isStopping: Bool
  let showStatistics: () -> Void
  let stop: () -> Void

  var body: some View {
    Group {
      if let interval {
        HStack(alignment: .top, spacing: 8) {
          Button(action: showStatistics) {
            VStack(alignment: .leading, spacing: 4) {
              Text(interval.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)

              trafficMetrics(interval)

              Text(timeDescription(interval))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .help("在主窗口查看 \(interval.name)")
          .accessibilityHint("在主窗口打开 Proxy 流量统计")

          taskControl(interval)
            .padding(.top, 1)
        }
        .accessibilityElement(children: .contain)
      } else {
        placeholder
      }
    }
    .frame(height: Self.height)
  }

  @ViewBuilder
  private func taskControl(_ interval: TrafficInterval) -> some View {
    switch interval.status {
    case .active:
      Button(action: stop) {
        HStack(spacing: 4) {
          if isStopping {
            ProgressView()
              .controlSize(.small)
          }
          Text(isStopping ? "正在停止…" : "停止")
        }
      }
      .controlSize(.small)
      .disabled(!isStatisticsAvailable || isStopping)
    case .completed:
      Label("已完成", systemImage: "checkmark.circle.fill")
        .font(.caption2)
        .foregroundStyle(MihomoColorToken.statusSuccess)
    case .interrupted:
      Label("已中断", systemImage: "exclamationmark.triangle.fill")
        .font(.caption2)
        .foregroundStyle(MihomoColorToken.statusWarning)
    }
  }

  private var placeholder: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("统计任务名称")
        .font(.subheadline.weight(.semibold))
      Text("下载、上传与合计")
        .font(.caption2)
      Text("任务状态与时长")
        .font(.caption2)
    }
    .hidden()
    .accessibilityHidden(true)
  }

  private func trafficMetrics(_ interval: TrafficInterval) -> some View {
    HStack(spacing: 10) {
      metric(
        symbolName: "arrow.down",
        bytes: interval.proxyUsage.download,
        color: MihomoColorToken.trafficDownload
      )
      metric(
        symbolName: "arrow.up",
        bytes: interval.proxyUsage.upload,
        color: MihomoColorToken.trafficUpload
      )
      Text("合计 \(TrafficStatisticsFormatter.bytes(interval.proxyUsage.total))")
        .foregroundStyle(MihomoColorToken.trafficProxy)
    }
    .font(.caption2.monospacedDigit().weight(.medium))
    .lineLimit(1)
  }

  private func metric(
    symbolName: String,
    bytes: UInt64,
    color: Color
  ) -> some View {
    Label(
      TrafficStatisticsFormatter.bytes(bytes),
      systemImage: symbolName
    )
    .foregroundStyle(color)
  }

  private func timeDescription(_ interval: TrafficInterval) -> String {
    let end = interval.endedAt ?? now
    let duration = TrafficStatisticsFormatter.duration(from: interval.startedAt, to: end)
    switch interval.status {
    case .active:
      return "\(TrafficStatisticsFormatter.dateTime(interval.startedAt)) 开始 · \(duration)"
    case .completed, .interrupted:
      return "\(duration) · \(TrafficStatisticsFormatter.dateTime(end)) 结束"
    }
  }
}
