import Charts
import SwiftUI

struct ConnectionAnalyticsTrendChart: View {
  let points: [ConnectionAnalyticsTrendPoint]
  @Binding var selectedLocalDay: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("最近 30 个本地自然日")
          .font(.subheadline.weight(.semibold))
        Spacer()
        legend(title: "下载", color: MihomoColorToken.trafficDownload)
        legend(title: "上传", color: MihomoColorToken.trafficUpload)
      }

      Chart {
        ForEach(Array(points.enumerated()), id: \.element.localDay) { index, point in
          ConnectionAnalyticsTrendBarMarks(index: index, point: point)
        }

        if let selectedIndex {
          RuleMark(x: .value("选中日期", Double(selectedIndex)))
            .foregroundStyle(.secondary.opacity(0.65))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
      }
      .chartLegend(.hidden)
      .chartXScale(domain: chartDomain)
      .chartXAxis {
        AxisMarks(values: sparseTickIndexes) { value in
          AxisGridLine().foregroundStyle(.clear)
          AxisTick()
          AxisValueLabel {
            if let rawIndex = value.as(Double.self) {
              let index = Int(rawIndex.rounded())
              if points.indices.contains(index) {
                Text(shortDay(points[index].localDay))
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
      .chartOverlay { proxy in
        GeometryReader { geometry in
          Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
              updateSelection(phase, proxy: proxy, geometry: geometry)
            }
        }
      }
      .focusable()
      .onMoveCommand(perform: moveSelection)
      .frame(minHeight: 230)
      .accessibilityLabel("应用或域名最近三十天每日上传下载堆叠柱图")
      .accessibilityValue(accessibilityValue)

      selectedDayDetail
    }
  }

  private var selectedDayDetail: some View {
    HStack(spacing: 18) {
      Text(selectedPoint?.localDay ?? "未选择日期")
        .font(.callout.weight(.semibold))
        .monospacedDigit()
      detailMetric(
        title: "下载",
        value: selectedPoint?.bytes.download ?? 0,
        color: MihomoColorToken.trafficDownload
      )
      detailMetric(
        title: "上传",
        value: selectedPoint?.bytes.upload ?? 0,
        color: MihomoColorToken.trafficUpload
      )
      detailMetric(
        title: "合计",
        value: selectedPoint?.bytes.total ?? 0,
        color: .primary
      )
      Spacer()
      Text("悬停柱图或使用左右方向键切换日期")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
  }

  private var selectedPoint: ConnectionAnalyticsTrendPoint? {
    points.first { $0.localDay == selectedLocalDay }
  }

  private var selectedIndex: Int? {
    points.firstIndex { $0.localDay == selectedLocalDay }
  }

  private var chartDomain: ClosedRange<Double> {
    -0.5...Double(max(points.count - 1, 0)) + 0.5
  }

  private var sparseTickIndexes: [Double] {
    guard !points.isEmpty else {
      return []
    }
    return Array(Set([0, 7, 14, 21, points.count - 1])).sorted().map(Double.init)
  }

  private var accessibilityValue: String {
    guard let selectedPoint else {
      return "未选择日期"
    }
    let download = TrafficStatisticsFormatter.bytes(selectedPoint.bytes.download)
    let upload = TrafficStatisticsFormatter.bytes(selectedPoint.bytes.upload)
    return "\(selectedPoint.localDay)，下载 \(download)，上传 \(upload)"
  }

  private func legend(title: String, color: Color) -> some View {
    HStack(spacing: 4) {
      Circle()
        .fill(color)
        .frame(width: 7, height: 7)
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func detailMetric(title: String, value: UInt64, color: Color) -> some View {
    HStack(spacing: 4) {
      Text(title)
        .foregroundStyle(.secondary)
      Text(TrafficStatisticsFormatter.bytes(value))
        .foregroundStyle(color)
        .monospacedDigit()
    }
    .font(.callout)
  }

  private func shortDay(_ localDay: String) -> String {
    let components = localDay.split(separator: "-")
    guard components.count == 3 else {
      return localDay
    }
    return "\(components[1])/\(components[2])"
  }

  private func updateSelection(
    _ phase: HoverPhase,
    proxy: ChartProxy,
    geometry: GeometryProxy
  ) {
    guard case .active(let location) = phase,
      let anchor = proxy.plotFrame
    else {
      return
    }
    let plotFrame = geometry[anchor]
    guard plotFrame.contains(location),
      let rawIndex = proxy.value(
        atX: location.x - plotFrame.minX,
        as: Double.self
      )
    else {
      return
    }
    let index = min(max(Int(rawIndex.rounded()), 0), points.count - 1)
    guard points.indices.contains(index) else {
      return
    }
    selectedLocalDay = points[index].localDay
  }

  private func moveSelection(_ direction: MoveCommandDirection) {
    guard !points.isEmpty else {
      return
    }
    let currentIndex = selectedIndex ?? points.count - 1
    let nextIndex: Int
    switch direction {
    case .left:
      nextIndex = max(currentIndex - 1, 0)
    case .right:
      nextIndex = min(currentIndex + 1, points.count - 1)
    default:
      return
    }
    selectedLocalDay = points[nextIndex].localDay
  }
}

private struct ConnectionAnalyticsTrendBarMarks: ChartContent {
  let index: Int
  let point: ConnectionAnalyticsTrendPoint

  var body: some ChartContent {
    BarMark(
      x: .value("日期", Double(index)),
      y: .value("流量", Double(point.bytes.download)),
      stacking: .standard
    )
    .foregroundStyle(MihomoColorToken.trafficDownload)

    BarMark(
      x: .value("日期", Double(index)),
      y: .value("流量", Double(point.bytes.upload)),
      stacking: .standard
    )
    .foregroundStyle(MihomoColorToken.trafficUpload)
  }
}
