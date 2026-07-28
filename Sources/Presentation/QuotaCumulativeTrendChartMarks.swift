import Charts
import SwiftUI

struct QuotaCumulativeTrendAreaValues: Equatable, Sendable {
  let baseline: Double
  let downloadEnd: Double
  let total: Double

  init(displayPoint: QuotaCumulativeTrendDisplayPoint) {
    let startTraffic = displayPoint.segmentStartPoint.traffic
    let currentTraffic = displayPoint.point.traffic
    let downloadIncrement =
      currentTraffic.downloadBytes >= startTraffic.downloadBytes
      ? currentTraffic.downloadBytes - startTraffic.downloadBytes
      : 0

    baseline = Double(startTraffic.usedBytes)
    downloadEnd = baseline + Double(downloadIncrement)
    total = Double(currentTraffic.usedBytes)
  }
}

struct QuotaDownloadIncrementAreaMark: ChartContent {
  let displayPoint: QuotaCumulativeTrendDisplayPoint
  let seriesID: String

  var body: some ChartContent {
    let values = QuotaCumulativeTrendAreaValues(displayPoint: displayPoint)
    AreaMark(
      x: .value("快照时间", displayPoint.point.date),
      yStart: .value("区间起点", values.baseline),
      yEnd: .value("下载增量", values.downloadEnd),
      series: .value("下载增量周期", "download-increment-\(seriesID)")
    )
    .foregroundStyle(Color.cyan.opacity(0.3))
    .interpolationMethod(.linear)
  }
}

struct QuotaUploadIncrementAreaMark: ChartContent {
  let displayPoint: QuotaCumulativeTrendDisplayPoint
  let seriesID: String

  var body: some ChartContent {
    let values = QuotaCumulativeTrendAreaValues(displayPoint: displayPoint)
    AreaMark(
      x: .value("快照时间", displayPoint.point.date),
      yStart: .value("上传起点", values.downloadEnd),
      yEnd: .value("总消耗", values.total),
      series: .value("上传增量周期", "upload-increment-\(seriesID)")
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

struct QuotaLatestPointMark: ChartContent {
  let displayPoint: QuotaCumulativeTrendDisplayPoint

  var body: some ChartContent {
    PointMark(
      x: .value("最新快照", displayPoint.point.date),
      y: .value("总消耗", Double(displayPoint.point.traffic.usedBytes))
    )
    .foregroundStyle(.blue)
    .symbolSize(38)
  }
}

struct QuotaCumulativeHoverMarks: ChartContent {
  let displayPoint: QuotaCumulativeTrendDisplayPoint

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
  }
}
