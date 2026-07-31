import SwiftUI

struct StatusMenuQuotaMetricsView: View {
  static let supportedWindows = [QuotaTrendWindow.day, .week]

  let quota: SubscriptionQuotaSnapshot
  let trends: RuntimeQuotaTrends
  let window: QuotaTrendWindow
  let onSelectWindow: (QuotaTrendWindow) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      quotaHeader

      SubscriptionQuotaProgressTrack(
        fraction: remainingFraction,
        isOverQuota: quota.traffic.isOverQuota,
        style: .compact
      )
      .accessibilityLabel("剩余流量比例")
      .accessibilityValue(remainingSummary)

      quotaMetrics

      Divider()

      rangeSummary

      QuotaCumulativeTrendChart(trend: trend, isCompact: true)
    }
  }

  private var quotaHeader: some View {
    HStack(alignment: .bottom, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text("剩余流量")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(SubscriptionQuotaFormatter.bytes(quota.traffic.remainingBytes))
          .font(.title2.weight(.semibold))
          .monospacedDigit()
      }

      Spacer(minLength: 8)

      Text(remainingSummary)
        .font(.caption2.monospacedDigit())
        .foregroundStyle(quota.traffic.isOverQuota ? MihomoColorToken.statusDanger : .primary)
        .lineLimit(1)
    }
  }

  private var quotaMetrics: some View {
    HStack(spacing: 10) {
      metric(
        title: "已用",
        value: SubscriptionQuotaFormatter.bytes(quota.traffic.usedBytes)
      )
      Divider().frame(height: 28)
      metric(
        title: "总量",
        value: SubscriptionQuotaFormatter.bytes(quota.traffic.totalBytes)
      )
      Divider().frame(height: 28)
      metric(
        title: "状态",
        value: quota.traffic.isOverQuota ? "已超额" : "可用",
        color: quota.traffic.isOverQuota ? MihomoColorToken.statusDanger : .primary
      )
    }
  }

  private var rangeSummary: some View {
    let usage = QuotaCumulativeTrendRangeUsage(segments: trend.segments)
    return VStack(alignment: .leading, spacing: 3) {
      HStack(alignment: .center, spacing: 6) {
        Text("累计总消耗走势")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)

        Spacer(minLength: 4)

        rangeSelector
      }

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(
          usage.isAvailable
            ? "本范围新增 \(SubscriptionQuotaFormatter.bytes(usage.traffic.total))"
            : "样本积累中"
        )
        .font(.caption2.monospacedDigit().weight(.semibold))
        .foregroundStyle(usage.isAvailable ? .primary : .secondary)
      }

      HStack(spacing: 18) {
        rangeMetric(
          title: "下载",
          value: usage.traffic.download,
          systemImage: "arrow.down",
          color: MihomoColorToken.trafficDownload,
          isAvailable: usage.isAvailable
        )
        rangeMetric(
          title: "上传",
          value: usage.traffic.upload,
          systemImage: "arrow.up",
          color: MihomoColorToken.trafficUpload,
          isAvailable: usage.isAvailable
        )
      }
    }
  }

  private var remainingFraction: Double {
    min(
      max(
        Double(quota.traffic.remainingBytes) / Double(quota.traffic.totalBytes),
        0
      ),
      1
    )
  }

  private var trend: QuotaTrend {
    trends.trend(for: window)
  }

  private var remainingSummary: String {
    guard !quota.traffic.isOverQuota else {
      return "已无剩余额度"
    }
    return "剩余 \(remainingFraction.formatted(.percent.precision(.fractionLength(1))))"
  }

  private func metric(
    title: String,
    value: String,
    color: Color = .primary
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.caption.monospacedDigit().weight(.semibold))
        .foregroundStyle(color)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func rangeMetric(
    title: String,
    value: UInt64,
    systemImage: String,
    color: Color,
    isAvailable: Bool
  ) -> some View {
    Label(
      "\(title) \(isAvailable ? SubscriptionQuotaFormatter.bytes(value) : "—")",
      systemImage: systemImage
    )
    .font(.caption2.monospacedDigit().weight(.medium))
    .foregroundStyle(color)
    .lineLimit(1)
  }

  private var rangeSelector: some View {
    HStack(spacing: 0) {
      rangeButton(.day)
      rangeButton(.week)
    }
    .padding(2)
    .frame(width: 132, height: 24)
    .background(
      Color.secondary.opacity(0.12),
      in: RoundedRectangle(cornerRadius: 6, style: .continuous)
    )
    .help("切换本地趋势范围，不会触发机场查询或改变预计可用天数")
  }

  private func rangeButton(_ option: QuotaTrendWindow) -> some View {
    let isSelected = window == option
    return Button {
      onSelectWindow(option)
    } label: {
      Text(rangeTitle(option))
        .font(.caption.weight(isSelected ? .medium : .regular))
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(
          isSelected ? Color.accentColor : Color.clear,
          in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityLabel("\(rangeTitle(option))\(isSelected ? "，当前范围" : "")")
  }

  private func rangeTitle(_ window: QuotaTrendWindow) -> String {
    switch window {
    case .day:
      "24 小时"
    case .week:
      "7 天"
    case .month:
      "30 天"
    case .year:
      "12 月"
    }
  }
}
