import Charts
import SwiftUI

struct QuotaCumulativeTrendChart: View {
  let trend: QuotaTrend
  var isCompact = false
  var isExpanded = false

  @State private var hoveredPointID: UUID?

  var body: some View {
    GeometryReader { geometry in
      let plotWidth = max(geometry.size.width - axisReserveWidth, 1)
      let model = QuotaCumulativeTrendChartModel(
        segments: trend.segments,
        targetPointCount: QuotaCumulativeTrendChartModel.targetPointCount(
          for: Double(plotWidth)
        )
      )

      VStack(alignment: .leading, spacing: 5) {
        if let dateDomain = model.dateDomain, model.points.count >= 2 {
          chart(model: model, dateDomain: dateDomain)
            .frame(height: plotHeight)
        } else {
          emptyState(sourcePointCount: model.sourcePointCount)
            .frame(height: plotHeight)
        }

        if isCompact {
          compactDetail(model: model)
        } else if let dateDomain = model.dateDomain {
          Text(
            SubscriptionQuotaFormatter.trendCoverage(
              from: dateDomain.lowerBound,
              to: dateDomain.upperBound,
              displayedPointCount: model.points.count,
              sourcePointCount: model.sourcePointCount
            )
          )
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        }
      }
    }
    .frame(height: chartHeight)
  }

  @ViewBuilder
  private func chart(
    model: QuotaCumulativeTrendChartModel,
    dateDomain: ClosedRange<Date>
  ) -> some View {
    let hoveredPoint = hoveredPoint(in: model)
    let chart = Chart {
      ForEach(model.segments) { segment in
        let seriesID = segmentSeriesID(segment.id)

        ForEach(segment.points) { displayPoint in
          QuotaDownloadAreaMark(displayPoint: displayPoint, seriesID: seriesID)
        }
        ForEach(segment.points) { displayPoint in
          QuotaUploadAreaMark(displayPoint: displayPoint, seriesID: seriesID)
        }
        ForEach(segment.points) { displayPoint in
          QuotaTotalLineMark(displayPoint: displayPoint, seriesID: seriesID)
        }
        if let firstPoint = segment.points.first {
          QuotaCycleStartMark(displayPoint: firstPoint)
        }
      }

      if !isCompact, let hoveredPoint {
        QuotaCumulativeHoverMarks(
          displayPoint: hoveredPoint,
          breakReason: breakReason(for: hoveredPoint.id, in: model),
          annotationAlignment: annotationAlignment(
            for: hoveredPoint.point.date,
            in: dateDomain
          )
        )
      }
    }
    .chartXScale(domain: dateDomain)
    .chartOverlay { proxy in
      GeometryReader { geometry in
        Rectangle()
          .fill(.clear)
          .contentShape(Rectangle())
          .onContinuousHover { phase in
            updateHover(
              phase,
              proxy: proxy,
              geometry: geometry,
              model: model
            )
          }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("机场累计用量走势")
    .accessibilityValue(accessibilityValue(model: model, dateDomain: dateDomain))

    if isCompact {
      chart
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    } else {
      chart
        .chartXAxis {
          AxisMarks(values: .automatic(desiredCount: 4)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            AxisValueLabel {
              if let date = value.as(Date.self) {
                Text(SubscriptionQuotaFormatter.trendTick(date, window: trend.window))
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
    }
  }

  @ViewBuilder
  private func compactDetail(model: QuotaCumulativeTrendChartModel) -> some View {
    if let displayPoint = hoveredPoint(in: model) ?? model.latestPoint {
      QuotaCumulativeTrendHoverView(
        displayPoint: displayPoint,
        breakReason: breakReason(for: displayPoint.id, in: model),
        isCompact: true
      )
    } else {
      Text("暂无可展示快照")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  private func emptyState(sourcePointCount: Int) -> some View {
    Text(sourcePointCount == 1 ? "已记录 1 个快照，继续积累后显示走势。" : "暂无可展示快照。")
      .font(.caption2)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
  }

  private func hoveredPoint(
    in model: QuotaCumulativeTrendChartModel
  ) -> QuotaCumulativeTrendDisplayPoint? {
    guard let hoveredPointID else {
      return nil
    }
    return model.points.first(where: { $0.id == hoveredPointID })
  }

  private func breakReason(
    for pointID: UUID,
    in model: QuotaCumulativeTrendChartModel
  ) -> QuotaCumulativeTrendDisplaySegment.BreakReason? {
    model.segments.first(where: { $0.points.first?.id == pointID })?.breakReason
  }

  private func annotationAlignment(
    for date: Date,
    in domain: ClosedRange<Date>
  ) -> Alignment {
    let midpoint = domain.lowerBound.addingTimeInterval(
      domain.upperBound.timeIntervalSince(domain.lowerBound) / 2
    )
    return date <= midpoint ? .topLeading : .topTrailing
  }

  private func updateHover(
    _ phase: HoverPhase,
    proxy: ChartProxy,
    geometry: GeometryProxy,
    model: QuotaCumulativeTrendChartModel
  ) {
    switch phase {
    case .active(let location):
      guard let plotFrame = resolvedPlotFrame(proxy: proxy, geometry: geometry),
        plotFrame.contains(location),
        let date = proxy.value(
          atX: location.x - plotFrame.minX,
          as: Date.self
        ),
        let nearestPoint = model.nearestPoint(to: date)
      else {
        hoveredPointID = nil
        return
      }
      hoveredPointID = nearestPoint.id
    case .ended:
      hoveredPointID = nil
    }
  }

  private func resolvedPlotFrame(
    proxy: ChartProxy,
    geometry: GeometryProxy
  ) -> CGRect? {
    if #available(macOS 14.0, *) {
      guard let anchor = proxy.plotFrame else {
        return nil
      }
      return geometry[anchor]
    }
    return geometry[proxy.plotAreaFrame]
  }

  private func segmentSeriesID(
    _ id: QuotaCumulativeTrendDisplaySegment.ID
  ) -> String {
    "\(id.cycleID.uuidString)-\(id.ordinal)"
  }

  private func accessibilityValue(
    model: QuotaCumulativeTrendChartModel,
    dateDomain: ClosedRange<Date>
  ) -> String {
    guard let latestPoint = model.latestPoint else {
      return "暂无真实快照"
    }
    let traffic = latestPoint.point.traffic
    return SubscriptionQuotaFormatter.trendCoverage(
      from: dateDomain.lowerBound,
      to: dateDomain.upperBound,
      displayedPointCount: model.points.count,
      sourcePointCount: model.sourcePointCount
    ) + "，累计下载 "
      + SubscriptionQuotaFormatter.bytes(traffic.downloadBytes) + "，累计上传 "
      + SubscriptionQuotaFormatter.bytes(traffic.uploadBytes) + "，总消耗 "
      + SubscriptionQuotaFormatter.bytes(traffic.usedBytes)
  }

  private var plotHeight: CGFloat {
    if isCompact {
      return 82
    }
    return isExpanded ? 245 : 190
  }

  private var chartHeight: CGFloat {
    if isCompact {
      return 143
    }
    return isExpanded ? 270 : 215
  }

  private var axisReserveWidth: CGFloat {
    isCompact ? 0 : 58
  }
}
