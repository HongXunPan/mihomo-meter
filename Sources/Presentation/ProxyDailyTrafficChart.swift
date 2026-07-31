import Charts
import SwiftUI

struct ProxyDailyTrafficChart: View {
  let days: [TrafficDailyTotal]

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Text("最近 30 天")
          .font(.caption.weight(.semibold))
        Spacer()
        chartLegend(title: "下载", color: MihomoColorToken.trafficDownload)
        chartLegend(title: "上传", color: MihomoColorToken.trafficUpload)
      }

      Chart {
        ForEach(Array(days.enumerated()), id: \.element.localDay) { index, day in
          ProxyDailyTrafficMarks(index: index, day: day)
        }
      }
      .chartLegend(.hidden)
      .chartXAxis {
        AxisMarks(values: sparseTickIndexes) { value in
          AxisGridLine().foregroundStyle(.clear)
          AxisTick()
          AxisValueLabel {
            if let rawIndex = value.as(Double.self) {
              let index = Int(rawIndex.rounded())
              if days.indices.contains(index) {
                Text(shortDay(days[index].localDay))
              }
            }
          }
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading) { value in
          AxisGridLine()
          AxisValueLabel {
            if let bytes = value.as(Double.self), bytes >= 0 {
              Text(TrafficStatisticsFormatter.bytes(UInt64(bytes)))
            }
          }
        }
      }
      .frame(height: 118)
      .accessibilityLabel("最近三十天 Proxy 每日上传下载堆叠柱图")
    }
  }

  private var sparseTickIndexes: [Double] {
    guard !days.isEmpty else {
      return []
    }
    return Array(Set([0, 7, 14, 21, days.count - 1])).sorted().map(Double.init)
  }

  private func chartLegend(title: String, color: Color) -> some View {
    HStack(spacing: 4) {
      Circle()
        .fill(color)
        .frame(width: 6, height: 6)
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  private func shortDay(_ localDay: String) -> String {
    let components = localDay.split(separator: "-")
    guard components.count == 3 else {
      return localDay
    }
    return "\(components[1])/\(components[2])"
  }
}

private struct ProxyDailyTrafficMarks: ChartContent {
  let index: Int
  let day: TrafficDailyTotal

  var body: some ChartContent {
    BarMark(
      x: .value("日期", Double(index)),
      y: .value("流量", Double(day.bytes.download)),
      width: .fixed(6),
      stacking: .standard
    )
    .foregroundStyle(MihomoColorToken.trafficDownload)

    BarMark(
      x: .value("日期", Double(index)),
      y: .value("流量", Double(day.bytes.upload)),
      width: .fixed(6),
      stacking: .standard
    )
    .foregroundStyle(MihomoColorToken.trafficUpload)
  }
}
