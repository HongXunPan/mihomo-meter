import SwiftUI

struct TrafficOverviewView: View {
  private enum Layout {
    static let rateColumnWidth: CGFloat = 88
    static let columnSpacing: CGFloat = 12
  }

  @ObservedObject var monitor: TrafficMonitor
  @Binding var showsDiagnostics: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      proxyRateSection
      categorySection
      qualitySection
      diagnosticsSection
    }
  }

  private var proxyRateSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Proxy 实时速度", systemImage: "network")
          .font(.headline)
        Spacer()
        Text("2 秒平均")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 12) {
        primaryMetric(
          title: "下载",
          symbol: "arrow.down",
          value: monitor.rates.proxy.downloadBytesPerSecond
        )
        primaryMetric(
          title: "上传",
          symbol: "arrow.up",
          value: monitor.rates.proxy.uploadBytesPerSecond
        )
      }
    }
  }

  private var categorySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("分类速度")
        .font(.headline)

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

  private var diagnosticsSection: some View {
    DisclosureGroup(isExpanded: $showsDiagnostics) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text("原始 1 秒 Proxy")

        Spacer(minLength: 8)

        Text(
          "↓ \(TrafficRateFormatter.string(from: monitor.rawRates.proxy.downloadBytesPerSecond))"
        )
        .monospacedDigit()

        Text(
          "↑ \(TrafficRateFormatter.string(from: monitor.rawRates.proxy.uploadBytesPerSecond))"
        )
        .monospacedDigit()
      }
      .padding(.top, 6)
      .padding(.leading, 14)
    } label: {
      Text("诊断信息")
    }
    .font(.caption)
    .accessibilityValue(showsDiagnostics ? "已展开" : "已折叠")
    .accessibilityHint("显示原始 1 秒 Proxy 速度")
  }

  private var qualitySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("分类可信度")
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

      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text("当前代理")
          .foregroundStyle(.secondary)

        Spacer(minLength: 12)

        Text(proxySummary)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(proxySummary)
      }
      .font(.caption)
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

  private var proxySummary: String {
    guard !monitor.activeProxyLeaves.isEmpty else {
      return "未检测到可确认出口"
    }
    return monitor.activeProxyLeaves.joined(separator: "、")
  }

  private func primaryMetric(
    title: String,
    symbol: String,
    value: UInt64
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Label(title, systemImage: symbol)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(TrafficRateFormatter.string(from: value))
        .font(.system(.title3, design: .rounded).weight(.semibold))
        .monospacedDigit()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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
