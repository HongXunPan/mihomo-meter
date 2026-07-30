import SwiftUI

struct ConnectionAnalyticsView: View {
  @ObservedObject var controller: ConnectionAnalyticsController
  let showTrend: (ConnectionAnalyticsTrendTarget) -> Void

  @State private var showsClearConfirmation = false

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 20)
        .padding(.vertical, 16)

      Divider()

      VStack(alignment: .leading, spacing: 14) {
        availabilityNotice
        ConnectionHistoryAnalyticsView(
          controller: controller,
          showTrend: showTrend
        )
      }
      .padding(20)
    }
    .frame(minWidth: 760, minHeight: 560)
    .confirmationDialog(
      "清空连接归因历史？",
      isPresented: $showsClearConfirmation
    ) {
      Button("清空", role: .destructive) {
        Task {
          await controller.clearHistory()
        }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("只删除应用与域名的日聚合，不影响核心流量总账、连接设置或访问密钥。")
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text("连接分析")
          .font(.title2.weight(.semibold))
        Text("查看可选保存的 Proxy 应用与域名日聚合；不保存连接明细。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Menu {
        Button("清空归因历史", role: .destructive) {
          showsClearConfirmation = true
        }
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .disabled(!controller.availability.isAvailable)
      .accessibilityLabel("更多连接归因操作")
    }
  }

  @ViewBuilder
  private var availabilityNotice: some View {
    switch controller.availability {
    case .loading:
      HStack(spacing: 8) {
        ProgressView()
          .controlSize(.small)
        Text("正在准备独立连接归因账本…")
      }
      .font(.callout)
    case .available:
      if let message = controller.operationMessage {
        notice(message, color: MihomoColorToken.statusWarning)
      } else if !controller.isHistoryEnabled {
        notice(
          "历史归因默认关闭；开启后只保存应用 × 完整主机名的日聚合，保留 30 天。",
          color: MihomoColorToken.statusNeutral
        )
      }
    case .unavailable(let message):
      notice(message, color: MihomoColorToken.statusDanger)
    }
  }

  private func notice(_ message: String, color: Color) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "info.circle")
      Text(message)
      Spacer()
    }
    .font(.callout)
    .foregroundStyle(color)
    .padding(10)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
  }
}
