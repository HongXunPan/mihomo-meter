import Charts
import SwiftUI

struct QuotaTrendChart: View {
  let trend: QuotaTrend
  var isCompact = false

  var body: some View {
    if trend.points.isEmpty {
      Text("记录更多有效快照后显示剩余流量走势。")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: chartHeight, alignment: .center)
    } else if isCompact {
      chart
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: chartHeight)
    } else {
      chart
        .chartYAxis {
          AxisMarks(position: .leading) { value in
            AxisGridLine()
            AxisValueLabel {
              if let bytes = value.as(Double.self), bytes >= 0 {
                Text(SubscriptionQuotaFormatter.bytes(UInt64(bytes)))
              }
            }
          }
        }
        .frame(height: chartHeight)
    }
  }

  private var chart: some View {
    Chart(trend.points) { point in
      AreaMark(
        x: .value("时间", point.date),
        y: .value("剩余流量", Double(point.traffic.remainingBytes))
      )
      .foregroundStyle(
        LinearGradient(
          colors: [.cyan.opacity(0.3), .cyan.opacity(0.02)],
          startPoint: .top,
          endPoint: .bottom
        )
      )

      LineMark(
        x: .value("时间", point.date),
        y: .value("剩余流量", Double(point.traffic.remainingBytes))
      )
      .foregroundStyle(.cyan)
      .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

      if trend.points.count == 1 {
        PointMark(
          x: .value("时间", point.date),
          y: .value("剩余流量", Double(point.traffic.remainingBytes))
        )
        .foregroundStyle(.cyan)
      }
    }
    .accessibilityLabel("剩余流量走势")
    .accessibilityValue("共 \(trend.points.count) 个有效快照")
  }

  private var chartHeight: CGFloat {
    isCompact ? 86 : 180
  }
}
