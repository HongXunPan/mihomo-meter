import SwiftUI

struct TrafficClassificationView: View {
  private enum Layout {
    static let rateColumnWidth: CGFloat = 88
    static let columnSpacing: CGFloat = 12
  }

  @ObservedObject var monitor: TrafficMonitor

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("分类速度")
          .font(.headline)

        Spacer()

        Label(
          TrafficRateFormatter.percentage(from: monitor.coverage),
          systemImage: coverageSymbol
        )
        .font(.subheadline.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(coverageColor)
        .help(coverageExplanation)
        .accessibilityLabel(
          "\(TrafficRateFormatter.percentage(from: monitor.coverage))。\(coverageExplanation)"
        )
      }

      HStack(spacing: Layout.columnSpacing) {
        Text("分类")
          .frame(maxWidth: .infinity, alignment: .leading)
        Label("下载", systemImage: "arrow.down")
          .frame(width: Layout.rateColumnWidth, alignment: .trailing)
        Label("上传", systemImage: "arrow.up")
          .frame(width: Layout.rateColumnWidth, alignment: .trailing)
      }
      .font(.caption2)
      .foregroundStyle(.secondary)

      VStack(spacing: 8) {
        categoryRow(title: "DIRECT", rate: monitor.rates.direct)
        categoryRow(title: "REJECT", rate: monitor.rates.reject)
        categoryRow(title: "未知", rate: monitor.rates.unknown)
      }
    }
  }

  private var coverageExplanation: String {
    switch coverageQuality {
    case .reliable:
      "覆盖率不低于 95%，当前分类结果较可靠。"
    case .low:
      "覆盖率低于 95%，当前结果不适合精确判断。"
    case .unavailable:
      "尚无足够流量计算分类覆盖率。"
    }
  }

  private var coverageQuality: TrafficCoverageQuality {
    TrafficCoveragePolicy.quality(for: monitor.coverage)
  }

  private var coverageSymbol: String {
    switch coverageQuality {
    case .reliable:
      "checkmark.circle.fill"
    case .low:
      "exclamationmark.triangle.fill"
    case .unavailable:
      "questionmark.circle"
    }
  }

  private var coverageColor: Color {
    switch coverageQuality {
    case .reliable:
      .green
    case .low:
      .orange
    case .unavailable:
      .secondary
    }
  }

  private func categoryRow(
    title: String,
    rate: TrafficRate
  ) -> some View {
    HStack(spacing: Layout.columnSpacing) {
      Text(title)
        .frame(maxWidth: .infinity, alignment: .leading)
      Text(TrafficRateFormatter.string(from: rate.downloadBytesPerSecond))
        .monospacedDigit()
        .frame(width: Layout.rateColumnWidth, alignment: .trailing)
      Text(TrafficRateFormatter.string(from: rate.uploadBytesPerSecond))
        .monospacedDigit()
        .frame(width: Layout.rateColumnWidth, alignment: .trailing)
    }
    .font(.caption)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(title)，下载 \(TrafficRateFormatter.string(from: rate.downloadBytesPerSecond))，"
        + "上传 \(TrafficRateFormatter.string(from: rate.uploadBytesPerSecond))"
    )
  }
}
