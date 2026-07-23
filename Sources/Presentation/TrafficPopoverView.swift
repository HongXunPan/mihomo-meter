import AppKit
import SwiftUI

struct TrafficPopoverView: View {
  let rate: TrafficRate

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Mihomo Meter")
        .font(.headline)

      Label("尚未连接 Mihomo", systemImage: "circle.dashed")
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 8) {
        metricRow(
          title: "Proxy 下载",
          value: TrafficRateFormatter.string(from: rate.downloadBytesPerSecond)
        )
        metricRow(
          title: "Proxy 上传",
          value: TrafficRateFormatter.string(from: rate.uploadBytesPerSecond)
        )
      }

      Divider()

      HStack {
        Text("当前为工程骨架，Controller 接入将在下一阶段实现。")
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer()

        Button("退出") {
          NSApplication.shared.terminate(nil)
        }
      }
    }
    .padding(16)
    .frame(width: 320)
  }

  private func metricRow(title: String, value: String) -> some View {
    HStack {
      Text(title)
      Spacer()
      Text(value)
        .monospacedDigit()
    }
  }
}
