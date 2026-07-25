import SwiftUI

struct TrafficIntervalRow: View {
  let interval: TrafficInterval
  let isStatisticsAvailable: Bool
  let stop: () -> Void
  let rename: () -> Void
  let delete: () -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Text(interval.name)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)

          statusLabel

          Spacer(minLength: 4)

          Menu {
            Button("重命名", action: rename)
            Button("删除", role: .destructive, action: delete)
          } label: {
            Image(systemName: "ellipsis.circle")
          }
          .menuStyle(.borderlessButton)
          .fixedSize()
          .accessibilityLabel("管理统计任务")
        }

        Text(timeDescription(now: context.date))
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)

        if canDisplayUsage {
          HStack(spacing: 12) {
            metric(
              title: "下载",
              symbol: "arrow.down",
              value: interval.proxyUsage.download
            )
            metric(
              title: "上传",
              symbol: "arrow.up",
              value: interval.proxyUsage.upload
            )
            metric(
              title: "合计",
              symbol: "sum",
              value: interval.proxyUsage.total
            )
          }
        } else {
          Label("统计链路异常，当前结果不可用", systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
        }

        if interval.status == .active, isStatisticsAvailable {
          HStack {
            Spacer()
            Button("停止统计", action: stop)
              .controlSize(.small)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
    }
  }

  @ViewBuilder
  private var statusLabel: some View {
    Label(statusTitle, systemImage: statusSymbol)
      .labelStyle(.titleAndIcon)
      .font(.caption2.weight(.medium))
      .foregroundStyle(statusColor)
  }

  private var canDisplayUsage: Bool {
    interval.status != .active || isStatisticsAvailable
  }

  private var statusTitle: String {
    if interval.status == .active, !isStatisticsAvailable {
      return "统计异常"
    }
    switch interval.status {
    case .active:
      return "进行中"
    case .completed:
      return "已完成"
    case .interrupted:
      return "已中断"
    }
  }

  private var statusSymbol: String {
    switch interval.status {
    case .active:
      return isStatisticsAvailable ? "stopwatch.fill" : "exclamationmark.triangle.fill"
    case .completed:
      return "checkmark.circle.fill"
    case .interrupted:
      return "exclamationmark.circle.fill"
    }
  }

  private var statusColor: Color {
    switch interval.status {
    case .active:
      return isStatisticsAvailable ? .blue : .orange
    case .completed:
      return .green
    case .interrupted:
      return .orange
    }
  }

  private func timeDescription(now: Date) -> String {
    let end = interval.endedAt ?? now
    let duration = TrafficStatisticsFormatter.duration(from: interval.startedAt, to: end)
    if let endedAt = interval.endedAt {
      return
        "\(TrafficStatisticsFormatter.dateTime(interval.startedAt)) 至 "
        + "\(TrafficStatisticsFormatter.dateTime(endedAt)) · \(duration)"
    }
    return "\(TrafficStatisticsFormatter.dateTime(interval.startedAt)) 开始 · \(duration)"
  }

  private func metric(
    title: String,
    symbol: String,
    value: UInt64
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Label(title, systemImage: symbol)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(TrafficStatisticsFormatter.bytes(value))
        .font(.caption.monospacedDigit().weight(.medium))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
