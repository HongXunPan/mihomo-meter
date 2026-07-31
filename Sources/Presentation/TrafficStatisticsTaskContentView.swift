import SwiftUI

struct TrafficStatisticsTaskContentView: View {
  @ObservedObject var controller: TrafficStatisticsController
  let isMonitoringAvailable: Bool

  @Binding var filter: TrafficStatisticsFilter
  @Binding var editor: TrafficIntervalEditor?
  @Binding var intervalPendingDeletion: TrafficInterval?

  var body: some View {
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
  }

  @ViewBuilder
  private var editorContent: some View {
    if let editor {
      switch editor.kind {
      case .create:
        TrafficIntervalNameEditor(
          title: "新建统计任务",
          name: editorNameBinding,
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
          name: editorNameBinding,
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

  private var editorNameBinding: Binding<String> {
    Binding(
      get: { editor?.draftName ?? "" },
      set: { draftName in
        guard var editor else {
          return
        }
        editor.draftName = draftName
        self.editor = editor
      }
    )
  }

  @ViewBuilder
  private var deletionConfirmation: some View {
    if let interval = intervalPendingDeletion {
      HStack(spacing: 10) {
        Image(systemName: "trash")
          .foregroundStyle(MihomoColorToken.statusDanger)
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
      .background(
        MihomoColorToken.statusDangerBackground,
        in: RoundedRectangle(cornerRadius: 9)
      )
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
