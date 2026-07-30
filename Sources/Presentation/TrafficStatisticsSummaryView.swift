import SwiftUI

struct TrafficStatisticsSummaryView: View {
  @ObservedObject var controller: TrafficStatisticsController
  let isMonitoringAvailable: Bool
  let showAllStatistics: () -> Void

  @State private var isStartingInterval = false

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

      ProxyDailyTrafficChart(days: controller.snapshot.recentProxyDays)

      activeIntervals
      showAllAction
    }
  }

  private var header: some View {
    HStack {
      Label("Proxy 流量统计", systemImage: "stopwatch")
        .font(.headline)

      Spacer()

      Button {
        startInterval()
      } label: {
        HStack(spacing: 5) {
          if isStartingInterval {
            ProgressView()
              .controlSize(.small)
          }
          Text(isStartingInterval ? "正在开始…" : "开始统计")
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .disabled(!canStartInterval || isStartingInterval)
    }
  }

  @ViewBuilder
  private var activeIntervals: some View {
    let intervals = TrafficStatisticsPresentation.quickActiveIntervals(
      from: controller.snapshot.intervals
    )

    if intervals.isEmpty {
      Text("暂无进行中的任务。")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .center)
    } else {
      VStack(spacing: 0) {
        ForEach(Array(intervals.enumerated()), id: \.element.id) { index, interval in
          TrafficIntervalRow(
            interval: interval,
            isStatisticsAvailable: controller.availability.isAvailable,
            stop: {
              Task {
                await controller.stopInterval(id: interval.id)
              }
            }
          )

          if index < intervals.count - 1 {
            Divider()
          }
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
    VStack(spacing: 8) {
      Divider()

      Button {
        showAllStatistics()
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "chart.bar.xaxis")
          Text("查看全部统计")

          Spacer()

          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.borderless)
      .accessibilityLabel("查看全部统计")
      .accessibilityHint("打开可缩放的完整统计窗口")
    }
  }

  private var canStartInterval: Bool {
    controller.availability.isAvailable && isMonitoringAvailable
  }

  private func startInterval() {
    guard canStartInterval, !isStartingInterval else {
      return
    }

    let name = TrafficStatisticsPresentation.suggestedIntervalName(
      from: controller.snapshot.intervals
    )
    isStartingInterval = true
    Task { @MainActor in
      await controller.startInterval(name: name)
      isStartingInterval = false
    }
  }
}
