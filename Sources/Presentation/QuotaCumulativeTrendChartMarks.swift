import Charts
import SwiftUI

struct QuotaDownloadAreaMark: ChartContent {
  let displayPoint: QuotaCumulativeTrendDisplayPoint
  let seriesID: String

  var body: some ChartContent {
    AreaMark(
      x: .value("快照时间", displayPoint.point.date),
      yStart: .value("下载起点", 0),
      yEnd: .value("累计下载", Double(displayPoint.point.traffic.downloadBytes)),
      series: .value("下载周期", "download-\(seriesID)")
    )
    .foregroundStyle(Color.cyan.opacity(0.3))
    .interpolationMethod(.linear)
  }
}

struct QuotaUploadAreaMark: ChartContent {
  let displayPoint: QuotaCumulativeTrendDisplayPoint
  let seriesID: String

  var body: some ChartContent {
    AreaMark(
      x: .value("快照时间", displayPoint.point.date),
      yStart: .value("上传起点", Double(displayPoint.point.traffic.downloadBytes)),
      yEnd: .value("总消耗", Double(displayPoint.point.traffic.usedBytes)),
      series: .value("上传周期", "upload-\(seriesID)")
    )
    .foregroundStyle(Color.indigo.opacity(0.24))
    .interpolationMethod(.linear)
  }
}

struct QuotaTotalLineMark: ChartContent {
  let displayPoint: QuotaCumulativeTrendDisplayPoint
  let seriesID: String

  var body: some ChartContent {
    LineMark(
      x: .value("快照时间", displayPoint.point.date),
      y: .value("总消耗", Double(displayPoint.point.traffic.usedBytes)),
      series: .value("总消耗周期", "total-\(seriesID)")
    )
    .foregroundStyle(.blue)
    .lineStyle(StrokeStyle(lineWidth: 2))
    .interpolationMethod(.linear)
  }
}

struct QuotaCycleStartMark: ChartContent {
  let displayPoint: QuotaCumulativeTrendDisplayPoint

  var body: some ChartContent {
    PointMark(
      x: .value("周期起点", displayPoint.point.date),
      y: .value("总消耗", Double(displayPoint.point.traffic.usedBytes))
    )
    .foregroundStyle(.blue)
    .symbolSize(38)

    PointMark(
      x: .value("周期起点", displayPoint.point.date),
      y: .value("总消耗", Double(displayPoint.point.traffic.usedBytes))
    )
    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
    .symbolSize(17)
  }
}

struct QuotaCumulativeHoverMarks: ChartContent {
  let displayPoint: QuotaCumulativeTrendDisplayPoint
  let breakReason: QuotaCumulativeTrendDisplaySegment.BreakReason?
  let annotationAlignment: Alignment

  var body: some ChartContent {
    RuleMark(x: .value("选中时间", displayPoint.point.date))
      .foregroundStyle(.secondary.opacity(0.5))
      .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

    PointMark(
      x: .value("选中时间", displayPoint.point.date),
      y: .value("总消耗", Double(displayPoint.point.traffic.usedBytes))
    )
    .foregroundStyle(.blue)
    .symbolSize(48)
    .annotation(
      position: .overlay,
      alignment: annotationAlignment,
      spacing: 10
    ) {
      QuotaCumulativeTrendHoverView(
        displayPoint: displayPoint,
        breakReason: breakReason
      )
      .allowsHitTesting(false)
    }
  }
}
