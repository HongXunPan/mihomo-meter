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

  init(
    title: String,
    trends: RuntimeQuotaTrends,
    initialWindow: QuotaTrendWindow
  ) {
    self.title = title
    self.trends = trends
    _window = State(initialValue: initialWindow)
  }

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(20)

      Divider()

      VStack(alignment: .leading, spacing: 16) {
        QuotaTrendRangeControl(window: $window)

        if let latestPoint {
          QuotaCumulativeTrendSummaryView(traffic: latestPoint.traffic)
        }

        QuotaCumulativeTrendChart(trend: trend, isExpanded: true)
      }
      .padding(20)
    }
    .frame(minWidth: 840, minHeight: 520)
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.title2.weight(.semibold))
        Text("订阅累计用量大图")
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

  private var latestPoint: QuotaTrendPoint? {
    trend.segments
      .flatMap(\.points)
      .max { $0.date < $1.date }
  }
}
