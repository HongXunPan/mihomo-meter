import SwiftUI

struct TrafficStatisticsTable: View {
  let intervals: [TrafficInterval]
  let isStatisticsAvailable: Bool
  let emptyMessage: String
  let stop: (TrafficInterval) -> Void
  let rename: (TrafficInterval) -> Void
  let delete: (TrafficInterval) -> Void

  var body: some View {
    if intervals.isEmpty {
      VStack(spacing: 8) {
        Image(systemName: "stopwatch")
          .font(.title)
          .foregroundStyle(.secondary)
        Text("没有统计任务")
          .font(.headline)
        Text(emptyMessage)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      Table(intervals) {
        TableColumn("名称") { interval in
          Text(interval.name)
            .lineLimit(1)
            .help(interval.name)
        }
        .width(min: 120, ideal: 180)

        TableColumn("状态") { interval in
          statusLabel(for: interval)
        }
        .width(90)

        TableColumn("开始时间") { interval in
          Text(TrafficStatisticsFormatter.dateTime(interval.startedAt))
            .lineLimit(1)
        }
        .width(min: 120, ideal: 145)

        TableColumn("持续时间") { interval in
          TrafficIntervalDurationText(interval: interval)
        }
        .width(90)

        TableColumn("下载") { interval in
          byteValue(interval.proxyUsage.download)
        }
        .width(80)

        TableColumn("上传") { interval in
          byteValue(interval.proxyUsage.upload)
        }
        .width(80)

        TableColumn("合计") { interval in
          byteValue(interval.proxyUsage.total)
        }
        .width(80)

        TableColumn("") { interval in
          actionMenu(for: interval)
        }
        .width(70)
      }
    }
  }

  private func statusLabel(for interval: TrafficInterval) -> some View {
    Label(
      statusTitle(for: interval),
      systemImage: statusSymbol(for: interval)
    )
    .font(.caption)
    .foregroundStyle(statusColor(for: interval))
  }

  private func byteValue(_ bytes: UInt64) -> some View {
    Text(TrafficStatisticsFormatter.bytes(bytes))
      .font(.body.monospacedDigit())
      .frame(maxWidth: .infinity, alignment: .trailing)
  }

  private func actionMenu(for interval: TrafficInterval) -> some View {
    HStack(spacing: 4) {
      if interval.status == .active {
        Button {
          stop(interval)
        } label: {
          Image(systemName: "stop.circle")
        }
        .buttonStyle(.borderless)
        .disabled(!isStatisticsAvailable)
        .help("停止统计")
        .accessibilityLabel("停止统计")
      }

      Menu {
        Button("重命名") {
          rename(interval)
        }
        Button("删除", role: .destructive) {
          delete(interval)
        }
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .accessibilityLabel("管理统计任务")
    }
  }

  private func statusTitle(for interval: TrafficInterval) -> String {
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

  private func statusSymbol(for interval: TrafficInterval) -> String {
    switch interval.status {
    case .active:
      return isStatisticsAvailable ? "stopwatch.fill" : "exclamationmark.triangle.fill"
    case .completed:
      return "checkmark.circle.fill"
    case .interrupted:
      return "exclamationmark.circle.fill"
    }
  }

  private func statusColor(for interval: TrafficInterval) -> Color {
    switch interval.status {
    case .active:
      return isStatisticsAvailable ? .blue : .orange
    case .completed:
      return .green
    case .interrupted:
      return .orange
    }
  }
}

private struct TrafficIntervalDurationText: View {
  let interval: TrafficInterval

  var body: some View {
    if let endedAt = interval.endedAt {
      duration(to: endedAt)
    } else {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        duration(to: context.date)
      }
    }
  }

  private func duration(to end: Date) -> some View {
    Text(TrafficStatisticsFormatter.duration(from: interval.startedAt, to: end))
      .font(.body.monospacedDigit())
      .lineLimit(1)
  }
}
