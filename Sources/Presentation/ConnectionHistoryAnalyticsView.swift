import SwiftUI

struct ConnectionHistoryAnalyticsView: View {
  @ObservedObject var controller: ConnectionAnalyticsController
  let showTrend: (ConnectionAnalyticsTrendTarget) -> Void

  @State private var selectedApplication = ""
  @State private var selectedHostname = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      controls
      coverageSummary
      filters

      HStack(alignment: .top, spacing: 14) {
        rankingPanel(
          title: "应用榜",
          items: applicationRanking,
          target: { item in
            ConnectionAnalyticsPresentation.applicationTrendTarget(
              applicationName: item.name,
              selectedHostname: selection(selectedHostname)
            )
          }
        )
        rankingPanel(
          title: "域名榜",
          items: hostnameRanking,
          target: { item in
            ConnectionAnalyticsPresentation.hostnameTrendTarget(
              hostname: item.name,
              selectedApplication: selection(selectedApplication)
            )
          }
        )
      }
    }
    .onChange(of: controller.selectedRecords) { _, records in
      if !records.contains(where: { $0.applicationName == selectedApplication }) {
        selectedApplication = ""
      }
      if !records.contains(where: { $0.hostname == selectedHostname }) {
        selectedHostname = ""
      }
    }
  }

  private var controls: some View {
    HStack(spacing: 12) {
      Picker("统计日期", selection: selectedDayBinding) {
        ForEach(controller.snapshot.recentDays, id: \.localDay) { day in
          Text(day.localDay).tag(day.localDay)
        }
      }
      .frame(width: 180)

      Text("本地自然日 · 最近 30 天")
        .font(.caption)
        .foregroundStyle(.secondary)

      Spacer()

      Toggle("记录日聚合", isOn: historyEnabledBinding)
        .toggleStyle(.switch)
        .disabled(!controller.availability.isAvailable)
    }
  }

  private var coverageSummary: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 24) {
        coverageMetric("归因记录覆盖", rate: controller.recordingCoverage?.rate)
        if let recordingCoverage = controller.recordingCoverage {
          recordingCoverageBytes(recordingCoverage)
        } else {
          Text("核心 Proxy 总账暂不可用，应用与域名榜仍可使用。")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Text("按流量字节计算 · 不代表记录时长")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Divider()

      HStack(spacing: 24) {
        coverageMetric("主机名流量覆盖", rate: selectedDay?.coverage.hostnameRate)
        coverageMetric("应用流量覆盖", rate: selectedDay?.coverage.applicationRate)
        coverageMetric("完整流量归因", rate: selectedDay?.coverage.fullyAttributedRate)
        Spacer()
        Text(
          "已记录归因：\(TrafficStatisticsFormatter.bytes(selectedDay?.bytes.total ?? 0))"
        )
        .font(.callout.weight(.medium))
      }
    }
    .padding(12)
    .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
  }

  private func recordingCoverageBytes(
    _ coverage: ConnectionAnalyticsRecordingCoverage
  ) -> some View {
    HStack(spacing: 16) {
      Text("已归因 \(TrafficStatisticsFormatter.bytes(coverage.attributed.total))")
      Text("核心 Proxy \(TrafficStatisticsFormatter.bytes(coverage.coreProxy.total))")
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .monospacedDigit()
  }

  private var filters: some View {
    HStack(spacing: 12) {
      Picker("应用筛选", selection: $selectedApplication) {
        Text("全部应用").tag("")
        ForEach(applicationNames, id: \.self) { name in
          Text(name).tag(name)
        }
      }
      .frame(maxWidth: 260)

      Picker("域名筛选", selection: $selectedHostname) {
        Text("全部域名").tag("")
        ForEach(hostnames, id: \.self) { hostname in
          Text(hostname).tag(hostname)
        }
      }
      .frame(maxWidth: 320)

      Button("重置筛选") {
        selectedApplication = ""
        selectedHostname = ""
      }
      .disabled(selectedApplication.isEmpty && selectedHostname.isEmpty)
    }
  }

  private func rankingPanel(
    title: String,
    items: [ConnectionAnalyticsRankingItem],
    target: @escaping (ConnectionAnalyticsRankingItem) -> ConnectionAnalyticsTrendTarget
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)

      if items.isEmpty {
        Text("该日期或筛选条件下暂无归因流量。")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(items) { item in
          ConnectionAnalyticsRankingButton(item: item) {
            showTrend(target(item))
          }
          .help(item.name)
        }
        .listStyle(.inset)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 250, maxHeight: .infinity)
  }

  private var selectedDayBinding: Binding<String> {
    Binding(
      get: { controller.selectedLocalDay ?? controller.snapshot.recentDays.last?.localDay ?? "" },
      set: { localDay in
        Task {
          await controller.selectDay(localDay)
        }
      }
    )
  }

  private var historyEnabledBinding: Binding<Bool> {
    Binding(
      get: { controller.isHistoryEnabled },
      set: { isEnabled in
        Task {
          await controller.setHistoryEnabled(isEnabled)
        }
      }
    )
  }

  private var selectedDay: ConnectionAnalyticsDay? {
    controller.snapshot.recentDays.first { $0.localDay == controller.selectedLocalDay }
  }

  private var applicationNames: [String] {
    ConnectionAnalyticsPresentation.applicationNames(from: controller.selectedRecords)
  }

  private var hostnames: [String] {
    ConnectionAnalyticsPresentation.hostnames(from: controller.selectedRecords)
  }

  private var applicationRanking: [ConnectionAnalyticsRankingItem] {
    ConnectionAnalyticsPresentation.applicationRanking(
      records: controller.selectedRecords,
      application: selection(selectedApplication),
      hostname: selection(selectedHostname)
    )
  }

  private var hostnameRanking: [ConnectionAnalyticsRankingItem] {
    ConnectionAnalyticsPresentation.hostnameRanking(
      records: controller.selectedRecords,
      application: selection(selectedApplication),
      hostname: selection(selectedHostname)
    )
  }

  private func coverageMetric(_ title: String, rate: Double?) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(TrafficRateFormatter.percentage(from: rate))
        .font(.title3.weight(.semibold))
        .monospacedDigit()
    }
  }

  private func selection(_ value: String) -> String? {
    value.isEmpty ? nil : value
  }
}

private struct ConnectionAnalyticsRankingButton: View {
  let item: ConnectionAnalyticsRankingItem
  let action: () -> Void

  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Text(item.name)
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text(TrafficStatisticsFormatter.bytes(item.bytes.total))
            .font(.callout.weight(.medium))
            .monospacedDigit()
          Text(
            "↓ \(TrafficStatisticsFormatter.bytes(item.bytes.download))  "
              + "↑ \(TrafficStatisticsFormatter.bytes(item.bytes.upload))"
          )
          .font(.caption2)
          .foregroundStyle(.secondary)
        }
        Image(systemName: "chart.bar.xaxis")
          .font(.caption)
          .foregroundStyle(isHovering ? MihomoColorToken.brandPrimary : .secondary)
      }
      .contentShape(Rectangle())
      .padding(.horizontal, 6)
      .padding(.vertical, 5)
      .background(
        isHovering ? Color.primary.opacity(0.06) : .clear,
        in: RoundedRectangle(cornerRadius: 6)
      )
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
    .accessibilityLabel("\(item.name)，合计 \(TrafficStatisticsFormatter.bytes(item.bytes.total))")
    .accessibilityHint("打开最近三十天趋势")
  }
}
