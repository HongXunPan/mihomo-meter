import SwiftUI

struct TrafficStatisticsSummaryView: View {
  @ObservedObject var controller: TrafficStatisticsController
  let isMonitoringAvailable: Bool
  let showAllStatistics: () -> Void

  @State private var isCreatingInterval = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      TrafficStatisticsNoticeView(
        controller: controller,
        isMonitoringAvailable: isMonitoringAvailable
      )
      TrafficStatisticsTotalsView(
        todayBytes: controller.snapshot.today.proxy.total,
        lifetimeBytes: controller.snapshot.lifetime.proxy.total
      )

      if isCreatingInterval {
        startEditor
      }

      activeIntervals
      showAllAction
    }
    .onDisappear {
      isCreatingInterval = false
    }
  }

  private var header: some View {
    HStack {
      Label("Proxy 流量统计", systemImage: "stopwatch")
        .font(.headline)

      Spacer()

      Button("开始统计") {
        isCreatingInterval = true
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .disabled(!canStartInterval || isCreatingInterval)
    }
  }

  private var startEditor: some View {
    TrafficIntervalNameEditor(
      title: "新建统计任务",
      initialName: suggestedName,
      actionTitle: "开始",
      cancel: {
        isCreatingInterval = false
      },
      submit: { name in
        await controller.startInterval(name: name)
        return controller.operationMessage == nil
      }
    )
  }

  @ViewBuilder
  private var activeIntervals: some View {
    let intervals = TrafficStatisticsPresentation.quickActiveIntervals(
      from: controller.snapshot.intervals
    )

    if intervals.isEmpty {
      Text("当前没有进行中的任务。历史记录可在完整统计中查看。")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    } else {
      LazyVStack(spacing: 8) {
        ForEach(intervals) { interval in
          TrafficIntervalRow(
            interval: interval,
            isStatisticsAvailable: controller.availability.isAvailable,
            stop: {
              Task {
                await controller.stopInterval(id: interval.id)
              }
            }
          )
        }
      }

      let additionalCount = TrafficStatisticsPresentation.additionalActiveCount(
        from: controller.snapshot.intervals
      )
      if additionalCount > 0 {
        Text("另有 \(additionalCount) 个任务正在统计。")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var showAllAction: some View {
    HStack {
      Spacer()
      Button("查看全部统计") {
        isCreatingInterval = false
        showAllStatistics()
      }
      .controlSize(.small)
      .accessibilityHint("打开可缩放的完整统计窗口")
    }
  }

  private var canStartInterval: Bool {
    controller.availability.isAvailable && isMonitoringAvailable
  }

  private var suggestedName: String {
    "统计任务 \(controller.snapshot.intervals.count + 1)"
  }
}
