import SwiftUI

struct StatusMenuTrafficTasksView: View {
  @ObservedObject var controller: TrafficStatisticsController
  let isMonitoringAvailable: () -> Bool
  let showStatistics: () -> Void

  @State private var isStartingInterval = false
  @State private var stoppingIntervalIDs: Set<UUID> = []

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let snapshot = TrafficStatisticsPresentation.quickTaskSnapshot(
        from: controller.snapshot.intervals,
        now: context.date
      )

      VStack(alignment: .leading, spacing: 10) {
        header
        Divider()
        taskSlots(snapshot, now: context.date)
        footer(snapshot)
      }
      .padding(14)
      .frame(
        width: StatusMenuLayout.trafficTasksSubmenuSize.width,
        height: StatusMenuLayout.trafficTasksSubmenuSize.height,
        alignment: .topLeading
      )
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text("最近统计任务")
          .font(.subheadline.weight(.semibold))
        Text("\(activeIntervalSummary) · 今日已结束任务补足")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button {
        startInterval()
      } label: {
        HStack(spacing: 5) {
          if isStartingInterval {
            ProgressView()
              .controlSize(.small)
          }
          Text(isStartingInterval ? "正在开始…" : "开始新统计")
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .disabled(!canStartInterval || isStartingInterval)
    }
    .frame(minHeight: 34)
  }

  private func taskSlots(
    _ snapshot: TrafficStatisticsQuickTaskSnapshot,
    now: Date
  ) -> some View {
    ZStack {
      VStack(spacing: 0) {
        ForEach(snapshot.slots.indices, id: \.self) { index in
          StatusMenuTrafficTaskRowView(
            interval: snapshot.slots[index],
            now: now,
            isStatisticsAvailable: controller.availability.isAvailable,
            isStopping: snapshot.slots[index].map {
              stoppingIntervalIDs.contains($0.id)
            } ?? false,
            showStatistics: showStatistics,
            stop: {
              guard let interval = snapshot.slots[index] else {
                return
              }
              stopInterval(id: interval.id)
            }
          )

          if index < snapshot.slots.count - 1 {
            Divider()
          }
        }
      }

      if snapshot.slots.allSatisfy({ $0 == nil }) {
        Text("今天暂无统计任务")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func footer(_ snapshot: TrafficStatisticsQuickTaskSnapshot) -> some View {
    Group {
      if snapshot.additionalCount > 0 {
        Text("另有 \(snapshot.additionalCount) 个任务，请在完整统计中查看")
      } else {
        Text("固定展示最近 5 个任务")
      }
    }
    .font(.caption2)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
  }

  private var canStartInterval: Bool {
    controller.availability.isAvailable && isMonitoringAvailable()
  }

  private var activeIntervalSummary: String {
    TrafficStatisticsPresentation.activeIntervalSummary(
      from: controller.snapshot.intervals
    )
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

  private func stopInterval(id: UUID) {
    guard !stoppingIntervalIDs.contains(id) else {
      return
    }
    stoppingIntervalIDs.insert(id)
    Task { @MainActor in
      await controller.stopInterval(id: id)
      stoppingIntervalIDs.remove(id)
    }
  }
}
