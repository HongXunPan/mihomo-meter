import SwiftUI

struct TrafficStatisticsView: View {
  @ObservedObject var controller: TrafficStatisticsController
  let isMonitoringAvailable: Bool

  @State private var draftName = ""
  @State private var intervalBeingRenamed: TrafficInterval?
  @State private var intervalPendingDeletion: TrafficInterval?
  @State private var showsStartDialog = false
  @State private var showsRenameDialog = false
  @State private var showsClearConfirmation = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      availabilityMessage
      proxyTotals
      intervalList
      clearAction
    }
    .alert("开始统计", isPresented: $showsStartDialog) {
      TextField("任务名称", text: $draftName)
      Button("取消", role: .cancel) {}
      Button("开始") {
        Task {
          await controller.startInterval(name: draftName)
        }
      }
    } message: {
      Text("任务只统计开始后的 Proxy 上传、下载和合计。")
    }
    .alert("重命名统计任务", isPresented: $showsRenameDialog) {
      TextField("任务名称", text: $draftName)
      Button("取消", role: .cancel) {}
      Button("保存") {
        guard let intervalBeingRenamed else {
          return
        }
        Task {
          await controller.renameInterval(id: intervalBeingRenamed.id, name: draftName)
        }
      }
    }
    .confirmationDialog(
      "删除统计任务？",
      isPresented: deletionConfirmationBinding
    ) {
      Button("删除", role: .destructive) {
        guard let intervalPendingDeletion else {
          return
        }
        Task {
          await controller.deleteInterval(id: intervalPendingDeletion.id)
          self.intervalPendingDeletion = nil
        }
      }
      Button("取消", role: .cancel) {
        intervalPendingDeletion = nil
      }
    } message: {
      Text("只删除该任务，不影响底层流量累计或其他任务。")
    }
    .confirmationDialog(
      "清空本地统计？",
      isPresented: $showsClearConfirmation
    ) {
      Button("清空", role: .destructive) {
        Task {
          await controller.clear()
        }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("账本和全部统计任务会被删除；服务地址与访问密钥（Secret）会保留。")
    }
  }

  private var header: some View {
    HStack {
      Label("Proxy 流量统计", systemImage: "stopwatch")
        .font(.headline)

      Spacer()

      Button("开始统计") {
        draftName = suggestedName
        showsStartDialog = true
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .disabled(!controller.availability.isAvailable || !isMonitoringAvailable)
    }
  }

  @ViewBuilder
  private var availabilityMessage: some View {
    switch controller.availability {
    case .loading:
      Label("正在读取本地统计…", systemImage: "clock")
        .font(.caption)
        .foregroundStyle(.secondary)
    case .available:
      if let message = controller.operationMessage {
        messageRow(message, color: .orange)
      } else if !isMonitoringAvailable {
        Label("连接 Mihomo 后可开始新的统计任务。", systemImage: "pause.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    case .unavailable(let message):
      messageRow(message, color: .red)
    }
  }

  private var proxyTotals: some View {
    HStack(spacing: 12) {
      totalMetric(title: "今日 Proxy", bytes: controller.snapshot.today.proxy.total)
      totalMetric(title: "本机累计 Proxy", bytes: controller.snapshot.lifetime.proxy.total)
    }
  }

  @ViewBuilder
  private var intervalList: some View {
    if controller.snapshot.intervals.isEmpty {
      Text("尚无统计任务。可同时开始多个任务，分别记录不同时间区间。")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    } else {
      LazyVStack(spacing: 8) {
        ForEach(controller.snapshot.intervals) { interval in
          TrafficIntervalRow(
            interval: interval,
            isStatisticsAvailable: controller.availability.isAvailable,
            stop: {
              Task {
                await controller.stopInterval(id: interval.id)
              }
            },
            rename: {
              intervalBeingRenamed = interval
              draftName = interval.name
              showsRenameDialog = true
            },
            delete: {
              intervalPendingDeletion = interval
            }
          )
        }
      }
    }
  }

  private var clearAction: some View {
    HStack {
      Spacer()
      Button("清空本地统计", role: .destructive) {
        showsClearConfirmation = true
      }
      .buttonStyle(.plain)
      .font(.caption)
    }
  }

  private var suggestedName: String {
    "统计任务 \(controller.snapshot.intervals.count + 1)"
  }

  private var deletionConfirmationBinding: Binding<Bool> {
    Binding(
      get: { intervalPendingDeletion != nil },
      set: { isPresented in
        if !isPresented {
          intervalPendingDeletion = nil
        }
      }
    )
  }

  private func totalMetric(title: String, bytes: UInt64) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(TrafficStatisticsFormatter.bytes(bytes))
        .font(.subheadline.monospacedDigit().weight(.semibold))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func messageRow(_ message: String, color: Color) -> some View {
    HStack(alignment: .top, spacing: 6) {
      Image(systemName: "exclamationmark.triangle.fill")
      Text(message)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 4)
      Button {
        controller.dismissOperationMessage()
      } label: {
        Image(systemName: "xmark")
      }
      .buttonStyle(.plain)
      .accessibilityLabel("关闭提示")
    }
    .font(.caption)
    .foregroundStyle(color)
  }
}
