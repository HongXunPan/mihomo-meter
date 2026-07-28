import SwiftUI

struct QuotaCumulativeTrendSummaryView: View {
  let traffic: QuotaTraffic

  var body: some View {
    HStack(spacing: 10) {
      metric(
        title: "总下载",
        value: traffic.downloadBytes,
        systemImage: "arrow.down",
        color: .cyan
      )
      Divider().frame(height: 28)
      metric(
        title: "总上传",
        value: traffic.uploadBytes,
        systemImage: "arrow.up",
        color: .indigo
      )
      Divider().frame(height: 28)
      metric(
        title: "总消耗",
        value: traffic.usedBytes,
        systemImage: "chart.line.uptrend.xyaxis",
        color: .blue
      )
    }
    .accessibilityElement(children: .combine)
  }

  private func metric(
    title: String,
    value: UInt64,
    systemImage: String,
    color: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Label(title, systemImage: systemImage)
        .font(.caption2)
        .foregroundStyle(color)
      Text(SubscriptionQuotaFormatter.bytes(value))
        .font(.caption.monospacedDigit().weight(.semibold))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
