import SwiftUI

struct TrafficClassificationView: View {
  private enum Layout {
    static let columnSpacing: CGFloat = 8
  }

  @ObservedObject var monitor: TrafficMonitor
  @Binding var isExpanded: Bool

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: Layout.columnSpacing) {
          Text("分类")
            .frame(maxWidth: .infinity, alignment: .leading)
          Label("下载", systemImage: "arrow.down")
            .frame(maxWidth: .infinity, alignment: .trailing)
          Label("上传", systemImage: "arrow.up")
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)

        VStack(spacing: 8) {
          categoryRow(title: "DIRECT", rate: monitor.rates.direct)
          categoryRow(title: "REJECT", rate: monitor.rates.reject)
          categoryRow(title: "未知", rate: monitor.rates.unknown)
        }
      }
      .padding(.top, 8)
      .padding(.leading, 14)
    } label: {
      HStack {
        Text("分类状态")
          .font(.subheadline.weight(.semibold))
          .fixedSize(horizontal: true, vertical: false)

        coverageLabel
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .accessibilityValue(isExpanded ? "已展开" : "已折叠")
    .accessibilityHint("显示 DIRECT、REJECT 和未知流量的下载与上传速度")
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
        .frame(maxWidth: .infinity, alignment: .trailing)
      Text(TrafficRateFormatter.string(from: rate.uploadBytesPerSecond))
        .monospacedDigit()
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
