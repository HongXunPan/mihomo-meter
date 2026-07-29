import SwiftUI

struct QuotaCumulativeTrendRangeUsage: Equatable, Sendable {
  let traffic: TrafficBytes
  let comparableIntervalCount: Int

  init(segments: [QuotaTrendSegment]) {
    var traffic = TrafficBytes.zero
    var comparableIntervalCount = 0

    for segment in segments {
      let points = segment.points.sorted(by: Self.pointOrder)
      for (previous, current) in zip(points, points.dropFirst()) {
        guard current.date > previous.date,
          let delta = TrafficBytes.nonnegativeDelta(
            current: TrafficBytes(
              upload: current.traffic.uploadBytes,
              download: current.traffic.downloadBytes
            ),
            previous: TrafficBytes(
              upload: previous.traffic.uploadBytes,
              download: previous.traffic.downloadBytes
            )
          )
        else {
          continue
        }
        traffic = traffic + delta
        comparableIntervalCount += 1
      }
    }

    self.traffic = traffic
    self.comparableIntervalCount = comparableIntervalCount
  }

  var isAvailable: Bool {
    comparableIntervalCount > 0
  }

  private static func pointOrder(_ left: QuotaTrendPoint, _ right: QuotaTrendPoint) -> Bool {
    if left.date == right.date {
      return left.id.uuidString < right.id.uuidString
    }
    return left.date < right.date
  }
}

struct QuotaCumulativeTrendSummaryView: View {
  let usage: QuotaCumulativeTrendRangeUsage

  init(trend: QuotaTrend) {
    usage = QuotaCumulativeTrendRangeUsage(segments: trend.segments)
  }

  var body: some View {
    HStack(spacing: 10) {
      metric(
        title: "下载增量",
        value: usage.traffic.download,
        systemImage: "arrow.down",
        color: MihomoColorToken.trafficDownload
      )
      Divider().frame(height: 28)
      metric(
        title: "上传增量",
        value: usage.traffic.upload,
        systemImage: "arrow.up",
        color: MihomoColorToken.trafficUpload
      )
      Divider().frame(height: 28)
      metric(
        title: "合计增量",
        value: usage.traffic.total,
        systemImage: "chart.line.uptrend.xyaxis",
        color: .primary
      )
    }
    .accessibilityElement(children: .combine)
  }

  private func metric(
    title: String,
    value: UInt64,
    systemImage: String,
    color: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Label(title, systemImage: systemImage)
        .font(.caption2)
        .foregroundStyle(color)
      Text(usage.isAvailable ? SubscriptionQuotaFormatter.bytes(value) : "—")
        .font(.caption.monospacedDigit().weight(.semibold))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
