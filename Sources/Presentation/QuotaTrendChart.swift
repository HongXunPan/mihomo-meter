import Charts
import SwiftUI

private struct QuotaUsageChartSegment: Identifiable {
  enum Kind: Hashable {
    case download
    case upload

    var color: Color {
      switch self {
      case .download:
        .cyan
      case .upload:
        .indigo
      }
    }
  }

  struct ID: Hashable {
    let barID: QuotaUsagePeriodID
    let kind: Kind
  }

  let id: ID
  let slotIndex: Double
  let startBytes: Double
  let endBytes: Double
  let opacity: Double

  var color: Color {
    id.kind.color
  }
}

private struct QuotaUsageBarMark: ChartContent {
  let segment: QuotaUsageChartSegment
  let width: MarkDimension

  var body: some ChartContent {
    BarMark(
      x: .value("自然时段", segment.slotIndex),
      yStart: .value("用量起点", segment.startBytes),
      yEnd: .value("用量终点", segment.endBytes),
      width: width
    )
    .foregroundStyle(segment.color)
    .opacity(segment.opacity)
  }
}

struct QuotaTrendChart: View {
  let trend: QuotaTrend
  let aggregation: QuotaUsageAggregation
  var isCompact = false
  var preferredBarWidth: CGFloat?

  @State private var hoveredSlotIndex: Int?

  private var series: QuotaUsageSeries {
    trend.usageSeries(for: aggregation)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      if series.bars.isEmpty {
        emptyState
      } else if isCompact {
        chart
          .chartXAxis(.hidden)
          .chartYAxis(.hidden)
          .frame(height: chartHeight)
      } else {
        chart
          .chartXAxis {
            AxisMarks(values: chartAxis.tickValues) { value in
              AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
              AxisValueLabel {
                if let index = value.as(Double.self).map({ Int($0.rounded()) }),
                  let slot = chartAxis.slot(at: index)
                {
                  Text(
                    SubscriptionQuotaFormatter.usageTick(
                      slot.interval.start,
                      aggregation: chartAxis.aggregation
                    )
                  )
                }
              }
            }
          }
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

        QuotaUsageHoverSummaryView(
          slot: hoveredSlot,
          aggregation: chartAxis.aggregation
        )
      }

      if let interval = series.unresolvedIntervals.first {
        Text(
          SubscriptionQuotaFormatter.unresolvedInterval(
            interval,
            additionalCount: series.unresolvedIntervals.count - 1
          )
        )
        .font(.caption2)
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var chart: some View {
    let segments = chartSegments
    let width = MarkDimension.fixed(preferredBarWidth ?? barWidth)

    return Chart {
      ForEach(segments) { segment in
        QuotaUsageBarMark(segment: segment, width: width)
      }

      if !isCompact, let hoveredSlot {
        RuleMark(x: .value("当前自然时段", Double(hoveredSlot.index)))
          .foregroundStyle(.secondary.opacity(0.5))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
      }
    }
    .chartXScale(domain: chartAxis.domain)
    .chartOverlay { proxy in
      GeometryReader { geometry in
        Rectangle()
          .fill(.clear)
          .contentShape(Rectangle())
          .onContinuousHover { phase in
            guard !isCompact else {
              return
            }
            switch phase {
            case .active(let location):
              guard let plotFrame = resolvedPlotFrame(proxy: proxy, geometry: geometry),
                plotFrame.contains(location),
                let value = proxy.value(
                  atX: location.x - plotFrame.minX,
                  as: Double.self
                ),
                let slot = chartAxis.nearestSlot(to: value)
              else {
                hoveredSlotIndex = nil
                return
              }
              hoveredSlotIndex = slot.index
            case .ended:
              hoveredSlotIndex = nil
            }
          }
      }
    }
    .accessibilityLabel("区间新增用量")
    .accessibilityValue(chartAccessibilityValue)
  }

  private var chartSegments: [QuotaUsageChartSegment] {
    var segments: [QuotaUsageChartSegment] = []
    segments.reserveCapacity(series.bars.count * 2)

    for slot in chartAxis.slots {
      guard let bar = slot.bar else {
        continue
      }
      let downloadBytes = Double(bar.downloadBytes)
      let opacity = bar.isBoundaryApproximation ? 0.72 : 1.0
      segments.append(
        QuotaUsageChartSegment(
          id: .init(barID: bar.id, kind: .download),
          slotIndex: Double(slot.index),
          startBytes: 0,
          endBytes: downloadBytes,
          opacity: opacity
        )
      )
      segments.append(
        QuotaUsageChartSegment(
          id: .init(barID: bar.id, kind: .upload),
          slotIndex: Double(slot.index),
          startBytes: downloadBytes,
          endBytes: Double(bar.totalBytes),
          opacity: opacity
        )
      )
    }

    return segments
  }

  private var chartAccessibilityValue: String {
    "共 " + String(chartAxis.slots.count) + " 个自然时段，其中 "
      + String(series.bars.count) + " 个有可比较数据，下载 "
      + SubscriptionQuotaFormatter.bytes(series.totalDownloadBytes) + "，上传 "
      + SubscriptionQuotaFormatter.bytes(series.totalUploadBytes) + "，"
      + "无法拆分区间 " + String(series.unresolvedIntervals.count) + " 段"
  }

  private var emptyState: some View {
    Text(
      series.unresolvedIntervals.isEmpty
        ? "至少需要两次同周期有效快照。"
        : "所选粒度无法可靠拆分当前快照区间。"
    )
    .font(.caption2)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, minHeight: chartHeight, alignment: .center)
  }

  private var chartHeight: CGFloat {
    isCompact ? 86 : 180
  }

  private var barWidth: CGFloat {
    let estimatedPlotWidth: CGFloat = isCompact ? 620 : 400
    let maximumWidth: CGFloat = 18
    let width = estimatedPlotWidth / CGFloat(max(chartAxis.slots.count, 1)) * 0.7
    return min(max(width, 2), maximumWidth)
  }

  private var chartAxis: QuotaUsageChartAxis {
    QuotaUsageChartAxis(series: series)
  }

  private var hoveredSlot: QuotaUsageChartSlot? {
    guard let hoveredSlotIndex else {
      return nil
    }
    return chartAxis.slot(at: hoveredSlotIndex)
  }

  private func resolvedPlotFrame(
    proxy: ChartProxy,
    geometry: GeometryProxy
  ) -> CGRect? {
    guard let anchor = proxy.plotFrame else {
      return nil
    }
    return geometry[anchor]
  }
}
