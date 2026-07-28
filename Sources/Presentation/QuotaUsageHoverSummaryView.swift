import SwiftUI

struct QuotaUsageHoverSummaryView: View {
  let slot: QuotaUsageChartSlot?
  let aggregation: QuotaUsageAggregation

  var body: some View {
    Group {
      if let slot {
        HStack(spacing: 10) {
          Text(
            SubscriptionQuotaFormatter.usageBucket(
              slot.interval,
              aggregation: aggregation
            )
          )
          .foregroundStyle(.primary)

          if let bar = slot.bar {
            Text("下载 \(SubscriptionQuotaFormatter.bytes(bar.downloadBytes))")
            Text("上传 \(SubscriptionQuotaFormatter.bytes(bar.uploadBytes))")
            Text("合计 \(SubscriptionQuotaFormatter.bytes(bar.totalBytes))")
            if bar.isBoundaryApproximation {
              Text("边界近似")
                .foregroundStyle(.orange)
            }
          } else {
            Text("无可归属数据")
          }
        }
      } else {
        Text("悬停图表可查看自然时段及上传、下载用量")
      }
    }
    .font(.caption2.monospacedDigit())
    .foregroundStyle(.secondary)
    .lineLimit(1)
    .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}
