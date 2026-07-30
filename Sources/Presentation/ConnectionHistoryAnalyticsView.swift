import SwiftUI

struct ConnectionHistoryAnalyticsView: View {
  @ObservedObject var controller: ConnectionAnalyticsController
  @State private var selectedApplication = ""
  @State private var selectedHostname = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      controls
      coverageSummary
      filters

      HStack(alignment: .top, spacing: 14) {
        rankingPanel(title: "应用榜", items: applicationRanking)
        rankingPanel(title: "域名榜", items: hostnameRanking)
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
    HStack(spacing: 24) {
      coverageMetric("主机名流量覆盖", rate: selectedDay?.coverage.hostnameRate)
      coverageMetric("应用流量覆盖", rate: selectedDay?.coverage.applicationRate)
      coverageMetric("完整流量归因", rate: selectedDay?.coverage.fullyAttributedRate)
      Spacer()
      Text("当日 Proxy：\(TrafficStatisticsFormatter.bytes(selectedDay?.bytes.total ?? 0))")
        .font(.callout.weight(.medium))
    }
    .padding(12)
    .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
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
    items: [ConnectionAnalyticsRankingItem]
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
          }
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
