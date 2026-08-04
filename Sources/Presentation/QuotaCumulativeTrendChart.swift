import Charts
import SwiftUI

struct QuotaCumulativeTrendChart: View {
  let trend: QuotaTrend
  var isCompact = false
  var isExpanded = false
  var externalInteraction: QuotaCumulativeTrendExternalInteraction?

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
        if let dateDomain = model.dateDomain,
          let totalUsageDomain = model.totalUsageDomain,
          model.points.count >= 2
        {
          chart(
            model: model,
            dateDomain: dateDomain,
            totalUsageDomain: totalUsageDomain
          )
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
    dateDomain: ClosedRange<Date>,
    totalUsageDomain: ClosedRange<Double>
  ) -> some View {
    let selectedPoint = selectedPoint(in: model)
    let chart = Chart {
      ForEach(model.segments) { segment in
        let seriesID = segmentSeriesID(segment.id)

        ForEach(segment.points) { displayPoint in
          QuotaDownloadIncrementAreaMark(
            displayPoint: displayPoint,
            seriesID: seriesID
          )
        }
        ForEach(segment.points) { displayPoint in
          QuotaUploadIncrementAreaMark(
            displayPoint: displayPoint,
            seriesID: seriesID
          )
        }
        ForEach(segment.points) { displayPoint in
          QuotaTotalLineMark(displayPoint: displayPoint, seriesID: seriesID)
        }
        if let firstPoint = segment.points.first {
          QuotaCycleStartMark(displayPoint: firstPoint)
        }
        if let firstPoint = segment.points.first,
          let lastPoint = segment.points.last,
          lastPoint.id != firstPoint.id
        {
          QuotaLatestPointMark(displayPoint: lastPoint)
        }
      }

      if let selectedPoint {
        QuotaCumulativeHoverMarks(
          displayPoint: selectedPoint
        )
      }
    }
    .chartXScale(
      domain: dateDomain,
      range: .plotDimension(startPadding: 6, endPadding: 6)
    )
    .chartYScale(domain: totalUsageDomain)
    .chartPlotStyle { plotContent in
      plotContent.clipped()
    }
    .chartOverlay { proxy in
      QuotaCumulativeTrendChartInteractionOverlay(
        proxy: proxy,
        model: model,
        selectedPoint: isCompact ? nil : selectedPoint,
        externalInteraction: externalInteraction,
        onInternalSelectedPointChange: updateInternalSelectedPoint
      )
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("机场累计总消耗走势")
    .accessibilityValue(accessibilityValue(model: model, dateDomain: dateDomain))

    chart
      .allowsHitTesting(!isCompact || externalInteraction != nil)
      .chartXAxis {
        AxisMarks(values: .automatic(desiredCount: isCompact ? 3 : 4)) { value in
          AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
          AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
          AxisValueLabel {
            if let date = value.as(Date.self) {
              Text(SubscriptionQuotaFormatter.trendTick(date, window: trend.window))
                .font(isCompact ? .caption2 : .caption)
            }
          }
        }
      }
      .chartYAxis {
        AxisMarks(
          position: .leading,
          values: .automatic(desiredCount: isCompact ? 2 : 4)
        ) { value in
          AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
          AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
          AxisValueLabel {
            if let bytes = value.as(Double.self), bytes >= 0 {
              Text(SubscriptionQuotaFormatter.bytes(UInt64(bytes)))
                .font(isCompact ? .caption2 : .caption)
            }
          }
        }
      }
  }

  @ViewBuilder
  private func compactDetail(model: QuotaCumulativeTrendChartModel) -> some View {
    if let displayPoint = selectedPoint(in: model) ?? model.latestPoint {
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

  private func selectedPoint(
    in model: QuotaCumulativeTrendChartModel
  ) -> QuotaCumulativeTrendDisplayPoint? {
    if let externalInteraction {
      return externalInteraction.selectedPointID.flatMap { pointID in
        model.points.first(where: { $0.id == pointID })
      } ?? model.latestPoint
    }
    return hoveredPointID.flatMap { pointID in
      model.points.first(where: { $0.id == pointID })
    }
  }

  private func breakReason(
    for pointID: UUID,
    in model: QuotaCumulativeTrendChartModel
  ) -> QuotaCumulativeTrendDisplaySegment.BreakReason? {
    model.segments.first(where: { $0.points.first?.id == pointID })?.breakReason
  }

  private func updateInternalSelectedPoint(_ pointID: UUID?) {
    guard externalInteraction == nil, hoveredPointID != pointID else {
      return
    }
    hoveredPointID = pointID
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
      return 108
    }
    return isExpanded ? 245 : 190
  }

  private var chartHeight: CGFloat {
    if isCompact {
      return 190
    }
    return isExpanded ? 270 : 215
  }

  private var axisReserveWidth: CGFloat {
    isCompact ? 52 : 58
  }
}
