import Foundation
import SwiftUI

struct ConnectionAttributionValidationView: View {
  @ObservedObject var monitor: TrafficMonitor

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 20)
        .padding(.vertical, 16)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          validationNotice
          metrics
          instructions
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .frame(minWidth: 680, minHeight: 520)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text("连接分析")
        .font(.title2.weight(.semibold))
      Text("阶段 3.0 仅验证 Proxy 连接的主机名与应用识别覆盖率。")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var validationNotice: some View {
    Label {
      Text("当前不会展示、记录或持久化主机名、进程名、进程路径和连接 ID。")
    } icon: {
      Image(systemName: "hand.raised.fill")
    }
    .font(.callout)
    .foregroundStyle(MihomoColorToken.statusWarning)
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      MihomoColorToken.statusWarningBackground,
      in: RoundedRectangle(cornerRadius: 10)
    )
  }

  private var metrics: some View {
    let coverage = monitor.attributionCoverage
    return VStack(alignment: .leading, spacing: 12) {
      Text("本次连接会话")
        .font(.headline)

      HStack(spacing: 12) {
        metric(title: "Proxy 连接样本", count: coverage.proxyConnectionCount, rate: nil)
        metric(
          title: "主机名可识别",
          count: coverage.hostnameIdentifiedCount,
          rate: coverage.hostnameRate
        )
        metric(
          title: "应用可识别",
          count: coverage.applicationIdentifiedCount,
          rate: coverage.applicationRate
        )
        metric(
          title: "两者同时可识别",
          count: coverage.fullyIdentifiedCount,
          rate: coverage.fullyIdentifiedRate
        )
      }

      if coverage.proxyConnectionCount == 0 {
        Text("尚未观测到 Proxy 连接。请保持 Mihomo 已连接并制造受控 Proxy 流量。")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var instructions: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("实机门禁")
        .font(.headline)
      Text("1. 打开一个明确经过 Proxy 的网页或下载任务。")
      Text("2. 观察样本数量和两项识别率是否持续产生非零结果。")
      Text("3. 若主机名或应用识别始终为零，应停止历史归因开发并调整阶段 3 范围。")
      Text("重连、数据过期、停止监控或内核计数重置会清空本次验证样本。")
        .foregroundStyle(.secondary)
    }
    .font(.callout)
  }

  private func metric(
    title: String,
    count: Int,
    rate: Double?
  ) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(rate.map(Self.percentage) ?? "\(count)")
        .font(.system(.title3, design: .rounded).weight(.semibold))
        .monospacedDigit()
      if rate != nil {
        Text("\(count) 条")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
  }

  private static func percentage(_ rate: Double) -> String {
    String(format: "%.1f%%", rate * 100)
  }
}
