import SwiftUI

struct SubscriptionQuotaMetricsView: View {
  let quota: SubscriptionQuotaSnapshot
  let trend: QuotaTrend
  var isCompact = false

  var body: some View {
    VStack(alignment: .leading, spacing: isCompact ? 9 : 13) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text("剩余流量")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(SubscriptionQuotaFormatter.bytes(quota.traffic.remainingBytes))
            .font(isCompact ? .title2 : .largeTitle)
            .monospacedDigit()
            .fontWeight(.semibold)
        }

        Spacer()

        Text(SubscriptionQuotaFormatter.updatedAt(quota.effectiveAt))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      ProgressView(value: remainingFraction)
        .tint(quota.traffic.isOverQuota ? .red : .accentColor)
        .accessibilityLabel("剩余流量比例")
        .accessibilityValue(
          quota.traffic.isOverQuota
            ? "已无剩余额度"
            : remainingFraction.formatted(.percent.precision(.fractionLength(0)))
        )

      HStack(spacing: 10) {
        metric(title: "已用", value: quota.traffic.usedBytes)
        Divider().frame(height: 28)
        metric(title: "总量", value: quota.traffic.totalBytes)
        Divider().frame(height: 28)
        VStack(alignment: .leading, spacing: 2) {
          Text("状态")
            .font(.caption2)
            .foregroundStyle(.secondary)
          Text(quota.traffic.isOverQuota ? "已超额" : "可用")
            .font(.caption.weight(.semibold))
            .foregroundStyle(quota.traffic.isOverQuota ? .red : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      usageChartHeader

      cumulativeTrendSummary

      QuotaCumulativeTrendChart(trend: trend, isCompact: isCompact)

      HStack {
        Spacer()
        Text(SubscriptionQuotaFormatter.depletion(trend))
      }
      .font(.caption2)
      .foregroundStyle(.secondary)

      if !isCompact {
        Text(SubscriptionQuotaFormatter.expiration(quota.expireAt))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var remainingFraction: Double {
    min(
      Double(quota.traffic.remainingBytes) / Double(quota.traffic.totalBytes),
      1
    )
  }

  private var usageChartHeader: some View {
    Text("累计总消耗走势")
      .font(.caption.weight(.medium))
      .foregroundStyle(.secondary)
  }

  private var cumulativeTrendSummary: some View {
    QuotaCumulativeTrendSummaryView(trend: trend)
  }

  private func metric(title: String, value: UInt64) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(SubscriptionQuotaFormatter.bytes(value))
        .font(.caption.monospacedDigit().weight(.semibold))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
