import SwiftUI

struct TrafficStatisticsNoticeView: View {
  @ObservedObject var controller: TrafficStatisticsController
  let isMonitoringAvailable: Bool

  @ViewBuilder
  var body: some View {
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
