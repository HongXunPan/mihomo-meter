import SwiftUI

struct TrafficClassificationView: View {
  private enum Layout {
    static let columnSpacing: CGFloat = 8
  }

  @ObservedObject var monitor: TrafficMonitor

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("分类覆盖率")
          .font(.caption.weight(.semibold))

        Spacer()
        coverageLabel
      }

      Text(coverageExplanation)
        .font(.caption2)
        .foregroundStyle(.secondary)

      Divider()

      HStack(spacing: Layout.columnSpacing) {
        Text("分类")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        Label("下载", systemImage: "arrow.down")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .trailing)
        Label("上传", systemImage: "arrow.up")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .font(.caption2)

      VStack(spacing: 8) {
        categoryRow(
          title: "DIRECT",
          rate: monitor.rates.direct,
          color: MihomoColorToken.trafficDirect
        )
        categoryRow(
          title: "REJECT",
          rate: monitor.rates.reject,
          color: MihomoColorToken.statusNeutral
        )
        categoryRow(
          title: "未知",
          rate: monitor.rates.unknown,
          color: MihomoColorToken.trafficUnknown
        )
      }
    }
    .padding(12)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("分类状态")
  }

  private var coverageLabel: some View {
    Label(
      TrafficRateFormatter.percentage(from: monitor.coverage),
      systemImage: coverageSymbol
    )
    .font(.caption.weight(.semibold))
    .monospacedDigit()
    .foregroundStyle(coverageColor)
    .help(coverageExplanation)
    .accessibilityLabel(
      "\(TrafficRateFormatter.percentage(from: monitor.coverage))。\(coverageExplanation)"
    )
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
      MihomoColorToken.statusSuccess
    case .low:
      MihomoColorToken.statusWarning
    case .unavailable:
      MihomoColorToken.statusNeutral
    }
  }

  private func categoryRow(
    title: String,
    rate: TrafficRate,
    color: Color
  ) -> some View {
    HStack(spacing: Layout.columnSpacing) {
      Text(title)
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
      Text(TrafficRateFormatter.string(from: rate.downloadBytesPerSecond))
        .monospacedDigit()
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .trailing)
      Text(TrafficRateFormatter.string(from: rate.uploadBytesPerSecond))
        .monospacedDigit()
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .font(.caption)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(title)，下载 \(TrafficRateFormatter.string(from: rate.downloadBytesPerSecond))，"
        + "上传 \(TrafficRateFormatter.string(from: rate.uploadBytesPerSecond))"
    )
  }
}
