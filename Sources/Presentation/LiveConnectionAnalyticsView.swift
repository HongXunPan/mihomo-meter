import SwiftUI

struct LiveConnectionAnalyticsView: View {
  @ObservedObject var monitor: TrafficMonitor

  @State private var selectedMode = LiveConnectionViewMode.connection
  @State private var searchText = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      coverageSummary
      applicationIdentificationDiagnostic
      viewControls

      if displayedItemCount == 0 {
        ContentUnavailableView(
          emptyTitle,
          systemImage: searchText.isEmpty
            ? "point.3.connected.trianglepath.dotted"
            : "magnifyingglass",
          description: Text(emptyDescription)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        tableContent
      }
    }
  }

  private var viewControls: some View {
    HStack(spacing: 12) {
      Picker("展示维度", selection: $selectedMode) {
        ForEach(LiveConnectionViewMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 260)

      Spacer()

      TextField("搜索应用或主机名", text: $searchText)
        .textFieldStyle(.roundedBorder)
        .frame(width: 280)
        .accessibilityHint("同时匹配当前 Proxy 连接的应用名称和主机名")
    }
  }

  @ViewBuilder
  private var tableContent: some View {
    switch selectedMode {
    case .connection:
      connectionTable
    case .application, .hostname:
      groupTable
    }
  }

  private var connectionTable: some View {
    Table(filteredConnections) {
      TableColumn("主机名") { connection in
        Text(connection.metadata.hostname ?? ConnectionAttributionLabel.unknownHostname)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      TableColumn("应用") { connection in
        Text(
          connection.metadata.applicationName
            ?? ConnectionAttributionLabel.unknownApplication
        )
        .lineLimit(1)
      }
      TableColumn("下载") { connection in
        rateText(connection.rate.downloadBytesPerSecond, color: MihomoColorToken.trafficDownload)
      }
      .width(min: 90, ideal: 110)
      TableColumn("上传") { connection in
        rateText(connection.rate.uploadBytesPerSecond, color: MihomoColorToken.trafficUpload)
      }
      .width(min: 90, ideal: 110)
      TableColumn("累计") { connection in
        Text(TrafficStatisticsFormatter.bytes(connection.cumulativeBytes.total))
          .monospacedDigit()
      }
      .width(min: 80, ideal: 100)
      TableColumn("时长") { connection in
        Text(duration(connection))
          .monospacedDigit()
      }
      .width(min: 72, ideal: 88)
    }
  }

  private var groupTable: some View {
    Table(groupRows) {
      TableColumn(selectedMode == .application ? "应用" : "域名") { row in
        Text(row.name)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      TableColumn(selectedMode == .application ? "域名数" : "应用数") { row in
        Text(row.relatedCount.formatted())
          .monospacedDigit()
      }
      .width(min: 72, ideal: 84)
      TableColumn("连接数") { row in
        Text(row.connectionCount.formatted())
          .monospacedDigit()
      }
      .width(min: 72, ideal: 84)
      TableColumn("下载") { row in
        rateText(row.rate.downloadBytesPerSecond, color: MihomoColorToken.trafficDownload)
      }
      .width(min: 90, ideal: 110)
      TableColumn("上传") { row in
        rateText(row.rate.uploadBytesPerSecond, color: MihomoColorToken.trafficUpload)
      }
      .width(min: 90, ideal: 110)
      TableColumn("活动累计") { row in
        Text(TrafficStatisticsFormatter.bytes(row.cumulativeBytes.total))
          .monospacedDigit()
      }
      .width(min: 90, ideal: 110)
    }
  }

  private var filteredConnections: [LiveProxyConnection] {
    LiveConnectionAnalyticsPresentation.connections(
      from: monitor.liveProxyConnections,
      searchText: searchText
    )
  }

  private var groupRows: [LiveConnectionGroupRow] {
    LiveConnectionAnalyticsPresentation.groups(
      from: monitor.liveProxyConnections,
      mode: selectedMode,
      searchText: searchText
    )
  }

  private var displayedItemCount: Int {
    selectedMode == .connection ? filteredConnections.count : groupRows.count
  }

  private var emptyTitle: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? "暂无 Proxy 连接"
      : "没有匹配的实时连接"
  }

  private var emptyDescription: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? "连接出现后会在这里实时展示；消失后立即移除，不保留明细。"
      : "请尝试其他应用名称或主机名。"
  }

  private var coverageSummary: some View {
    HStack(spacing: 12) {
      coverageMetric("主机名", rate: monitor.attributionCoverage.hostnameRate)
      coverageMetric("应用", rate: monitor.attributionCoverage.applicationRate)
      coverageMetric("两者同时", rate: monitor.attributionCoverage.fullyIdentifiedRate)
      Spacer()
      Text("本次连接会话 · 不保存明细")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var applicationIdentificationDiagnostic: some View {
    let diagnostic = ApplicationIdentificationDiagnostic(
      mode: monitor.runtimeConfiguration?.processMatchingMode,
      coverage: monitor.attributionCoverage
    )
    return HStack(alignment: .top, spacing: 10) {
      Image(systemName: diagnostic.isWarning ? "exclamationmark.triangle.fill" : "info.circle")
        .foregroundStyle(
          diagnostic.isWarning ? MihomoColorToken.statusWarning : MihomoColorToken.statusNeutral
        )
      VStack(alignment: .leading, spacing: 2) {
        Text(diagnostic.title)
          .font(.callout.weight(.medium))
        Text(diagnostic.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      diagnostic.isWarning ? MihomoColorToken.statusWarningBackground : Color.clear,
      in: RoundedRectangle(cornerRadius: 8)
    )
    .accessibilityElement(children: .combine)
  }

  private func coverageMetric(_ title: String, rate: Double?) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(TrafficRateFormatter.percentage(from: rate))
        .font(.callout.weight(.semibold))
        .monospacedDigit()
    }
  }

  private func rateText(_ bytesPerSecond: UInt64, color: Color) -> some View {
    Text(TrafficRateFormatter.string(from: bytesPerSecond))
      .monospacedDigit()
      .foregroundStyle(color)
  }

  private func duration(_ connection: LiveProxyConnection) -> String {
    guard let startedAt = connection.startedAt else {
      return "—"
    }
    return TrafficStatisticsFormatter.duration(from: startedAt, to: Date())
  }
}
