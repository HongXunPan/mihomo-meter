import SwiftUI

struct TrafficStatisticsView: View {
  @ObservedObject var controller: TrafficStatisticsController
  @ObservedObject var monitor: TrafficMonitor

  @State private var filter = TrafficStatisticsFilter.all
  @State private var editor: TrafficIntervalEditor?
  @State private var intervalPendingDeletion: TrafficInterval?
  @State private var showsClearConfirmation = false

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 20)
        .padding(.vertical, 16)

      Divider()

      VStack(alignment: .leading, spacing: 14) {
        TrafficStatisticsNoticeView(
          controller: controller,
          isMonitoringAvailable: isMonitoringAvailable
        )
        TrafficStatisticsTotalsView(
          todayBytes: controller.snapshot.today.proxy.total,
          lifetimeBytes: controller.snapshot.lifetime.proxy.total,
          activeCount: controller.activeIntervals.count
        )
        editorContent
        deletionConfirmation
        filterPicker
        table
      }
      .padding(20)
    }
    .frame(minWidth: 820, minHeight: 520)
    .confirmationDialog(
      "清空本地统计？",
      isPresented: $showsClearConfirmation
    ) {
      Button("清空", role: .destructive) {
        Task {
          await controller.clear()
          guard controller.operationMessage == nil else {
            return
          }
          editor = nil
          intervalPendingDeletion = nil
        }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("账本和全部统计任务会被删除；服务地址与访问密钥（Secret）会保留。")
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Proxy 流量统计")
          .font(.title2.weight(.semibold))
        Text("管理秒表式统计任务，并查看本机 Proxy 累计。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button("开始统计") {
        intervalPendingDeletion = nil
        editor = .create(initialName: suggestedName)
      }
      .buttonStyle(.borderedProminent)
      .disabled(!canStartInterval)

      Menu {
        Button("清空本地统计", role: .destructive) {
          showsClearConfirmation = true
        }
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .accessibilityLabel("更多统计操作")
    }
  }

  @ViewBuilder
  private var editorContent: some View {
    if let editor {
      switch editor {
      case .create(let initialName):
        TrafficIntervalNameEditor(
          title: "新建统计任务",
          initialName: initialName,
          actionTitle: "开始",
          cancel: {
            self.editor = nil
          },
          submit: { name in
            await controller.startInterval(name: name)
            let succeeded = controller.operationMessage == nil
            if succeeded {
              filter = .active
            }
            return succeeded
          }
        )
        .id(editor.id)
      case .rename(let interval):
        TrafficIntervalNameEditor(
          title: "重命名“\(interval.name)”",
          initialName: interval.name,
          actionTitle: "保存",
          cancel: {
            self.editor = nil
          },
          submit: { name in
            await controller.renameInterval(id: interval.id, name: name)
            return controller.operationMessage == nil
          }
        )
        .id(editor.id)
      }
    }
  }

  @ViewBuilder
  private var deletionConfirmation: some View {
    if let interval = intervalPendingDeletion {
      HStack(spacing: 10) {
        Image(systemName: "trash")
          .foregroundStyle(.red)
        Text("确认删除“\(interval.name)”？只删除该任务，不影响底层累计。")
          .font(.callout)
          .lineLimit(2)

        Spacer()

        Button("取消") {
          intervalPendingDeletion = nil
        }
        Button("删除", role: .destructive) {
          Task {
            await controller.deleteInterval(id: interval.id)
            if controller.operationMessage == nil {
              intervalPendingDeletion = nil
            }
          }
        }
      }
      .padding(10)
      .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
    }
  }

  private var filterPicker: some View {
    Picker("统计任务范围", selection: $filter) {
      ForEach(TrafficStatisticsFilter.allCases) { filter in
        Text(filter.title).tag(filter)
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .frame(maxWidth: 360)
  }

  private var table: some View {
    TrafficStatisticsTable(
      intervals: filter.intervals(from: controller.snapshot.intervals),
      isStatisticsAvailable: controller.availability.isAvailable,
      emptyMessage: emptyMessage,
      stop: { interval in
        Task {
          await controller.stopInterval(id: interval.id)
        }
      },
      rename: { interval in
        intervalPendingDeletion = nil
        editor = .rename(interval)
      },
      delete: { interval in
        editor = nil
        intervalPendingDeletion = interval
      }
    )
  }

  private var isMonitoringAvailable: Bool {
    switch monitor.connectionState {
    case .connected, .stale, .reconnecting:
      true
    case .disconnected, .connecting, .authenticationFailed, .unsupported:
      false
    }
  }

  private var canStartInterval: Bool {
    controller.availability.isAvailable && isMonitoringAvailable && editor == nil
  }

  private var suggestedName: String {
    "统计任务 \(controller.snapshot.intervals.count + 1)"
  }

  private var emptyMessage: String {
    switch filter {
    case .active:
      return "当前没有进行中的任务。"
    case .history:
      return "尚无已完成或已中断的任务。"
    case .all:
      return "点击“开始统计”创建第一个任务。"
    }
  }
}

private enum TrafficIntervalEditor: Identifiable {
  case create(initialName: String)
  case rename(TrafficInterval)

  var id: String {
    switch self {
    case .create:
      return "create"
    case .rename(let interval):
      return "rename-\(interval.id.uuidString)"
    }
  }
}
