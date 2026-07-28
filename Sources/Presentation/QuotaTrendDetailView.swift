import SwiftUI

enum QuotaTrendChartLayout {
  static let minimumViewportWidth: CGFloat = 760
  static let horizontalSlotWidth: CGFloat = 16
  static let axisReserveWidth: CGFloat = 72

  static func contentWidth(slotCount: Int) -> CGFloat {
    max(
      minimumViewportWidth,
      CGFloat(max(slotCount, 1)) * horizontalSlotWidth + axisReserveWidth
    )
  }
}

struct QuotaTrendDetailView: View {
  let title: String
  let trends: RuntimeQuotaTrends

  @Environment(\.dismiss) private var dismiss
  @State private var window: QuotaTrendWindow
  @State private var aggregation: QuotaUsageAggregation

  init(
    title: String,
    trends: RuntimeQuotaTrends,
    initialWindow: QuotaTrendWindow
  ) {
    self.title = title
    self.trends = trends
    _window = State(initialValue: initialWindow)
    _aggregation = State(
      initialValue: Self.preferredAggregation(
        for: initialWindow,
        trends: trends
      )
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(20)

      Divider()

      VStack(alignment: .leading, spacing: 16) {
        QuotaTrendRangeControl(window: $window)

        HStack {
          QuotaTrendAggregationControl(
            aggregation: $aggregation,
            availableAggregations: availableAggregations
          )
          Spacer()
          Text(SubscriptionQuotaFormatter.usageSummary(series))
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        ScrollView(.horizontal) {
          QuotaTrendChart(
            trend: trend,
            aggregation: aggregation,
            preferredBarWidth: 10
          )
          .frame(
            width: QuotaTrendChartLayout.contentWidth(
              slotCount: chartAxis.slots.count
            )
          )
        }
      }
      .padding(20)
    }
    .frame(minWidth: 840, minHeight: 520)
    .onChange(of: window) { newWindow in
      aggregation = Self.preferredAggregation(for: newWindow, trends: trends)
    }
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.title2.weight(.semibold))
        Text("订阅新增用量大图")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button("完成") {
        dismiss()
      }
      .keyboardShortcut(.cancelAction)
    }
  }

  private var trend: QuotaTrend {
    trends.trend(for: window)
  }

  private var series: QuotaUsageSeries {
    trend.usageSeries(for: aggregation)
  }

  private var chartAxis: QuotaUsageChartAxis {
    QuotaUsageChartAxis(series: series)
  }

  private var availableAggregations: Set<QuotaUsageAggregation> {
    Set(
      QuotaUsageAggregation.selectableCases.filter {
        trend.usageSeries(for: $0).isAvailable
      }
    )
  }

  private static func preferredAggregation(
    for window: QuotaTrendWindow,
    trends: RuntimeQuotaTrends
  ) -> QuotaUsageAggregation {
    let preferred = window.defaultUsageAggregation
    let trend = trends.trend(for: window)
    return trend.usageSeries(for: preferred).bars.isEmpty ? .automatic : preferred
  }
}
