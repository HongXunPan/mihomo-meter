import SwiftUI

struct StatusMenuQuotaMetricsView: View {
  static let supportedWindows = [QuotaTrendWindow.day, .week]

  let quota: SubscriptionQuotaSnapshot
  let target: StatusMenuQuotaTrendTarget
  @ObservedObject var state: StatusMenuQuotaTrendState
  let status: ProfileQuotaStatusPresentation?
  let confirmCurrentCycle: @MainActor (UUID) async -> String?
  @ObservedObject private var hoverState: StatusMenuQuotaTrendHoverState

  init(
    quota: SubscriptionQuotaSnapshot,
    target: StatusMenuQuotaTrendTarget,
    state: StatusMenuQuotaTrendState,
    status: ProfileQuotaStatusPresentation?,
    confirmCurrentCycle: @escaping @MainActor (UUID) async -> String?
  ) {
    self.quota = quota
    self.target = target
    self.state = state
    self.status = status
    self.confirmCurrentCycle = confirmCurrentCycle
    hoverState = state.hoverState
  }

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

      StatusMenuQuotaStatusView(
        target: target,
        status: status,
        referenceDate: state.referenceDate,
        confirmCurrentCycle: confirmCurrentCycle
      )

      Divider()

      rangeSummary

      QuotaCumulativeTrendChart(
        trend: trend,
        isCompact: true,
        externalInteraction: externalInteraction
      )
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
    HStack(spacing: 8) {
      metric(
        title: "已用",
        value: SubscriptionQuotaFormatter.bytes(quota.traffic.usedBytes)
      )
      Spacer(minLength: 8)
      metric(
        title: "总量",
        value: SubscriptionQuotaFormatter.bytes(quota.traffic.totalBytes)
      )
    }
  }

  private var rangeSummary: some View {
    let usage = QuotaCumulativeTrendRangeUsage(segments: trend.segments)
    return VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .center, spacing: 6) {
        Text("累计用量走势")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)

        Spacer(minLength: 4)

        rangeSelector
      }

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(
          usage.isAvailable
            ? "范围内新增 \(SubscriptionQuotaFormatter.bytes(usage.traffic.total))"
            : "样本积累中"
        )
        .font(.caption2.monospacedDigit().weight(.semibold))
        .foregroundStyle(usage.isAvailable ? .primary : .secondary)
      }

      HStack(spacing: 8) {
        rangeMetric(
          title: "下载",
          value: usage.traffic.download,
          systemImage: "arrow.down",
          color: MihomoColorToken.trafficDownload,
          isAvailable: usage.isAvailable
        )
        Spacer(minLength: 8)
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
    target.trends.trend(for: state.window)
  }

  private var externalInteraction: QuotaCumulativeTrendExternalInteraction? {
    guard let hoverContext = state.hoverContext else {
      return nil
    }
    return QuotaCumulativeTrendExternalInteraction(
      selectedPointID: hoverState.selectedPointID,
      onSelectedPointChange: { pointID in
        hoverState.select(pointID, in: hoverContext)
      }
    )
  }

  private var remainingSummary: String {
    guard !quota.traffic.isOverQuota else {
      return "已无剩余额度"
    }
    return "剩余 \(remainingFraction.formatted(.percent.precision(.fractionLength(1))))"
  }

  private func metric(
    title: String,
    value: String
  ) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.caption.monospacedDigit())
        .lineLimit(1)
    }
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
    .frame(width: 120, height: 22)
    .background(
      Color.secondary.opacity(0.12),
      in: RoundedRectangle(cornerRadius: 6, style: .continuous)
    )
    .help("切换本地趋势范围，不会触发机场查询或改变预计可用时长")
  }

  private func rangeButton(_ option: QuotaTrendWindow) -> some View {
    let isSelected = state.window == option
    return Button {
      state.selectWindow(option)
    } label: {
      Text(rangeTitle(option))
        .font(.caption2)
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
