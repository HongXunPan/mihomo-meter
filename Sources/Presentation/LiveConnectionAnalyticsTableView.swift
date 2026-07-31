import SwiftUI

struct LiveConnectionAnalyticsTableView: View {
  let selectedRoute: LiveConnectionRoute

  @Binding var selectedMode: LiveConnectionViewMode
  @Binding var searchText: String

  let connections: [LiveTrafficConnection]
  let groupRows: [LiveConnectionGroupRow]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      tableToolbar

      if displayedItemCount == 0 {
        ContentUnavailableView(
          emptyTitle,
          systemImage: normalizedSearchText.isEmpty
            ? "point.3.connected.trianglepath.dotted"
            : "magnifyingglass",
          description: Text(emptyDescription)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        tableContent
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var tableToolbar: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        modePicker
        Spacer()
        wideSearchField
      }

      VStack(alignment: .leading, spacing: 8) {
        modePicker
        compactSearchField
      }
    }
  }

  private var modePicker: some View {
    Picker("展示维度", selection: $selectedMode) {
      ForEach(LiveConnectionViewMode.allCases) { mode in
        Text(mode.title).tag(mode)
      }
    }
    .pickerStyle(.segmented)
    .frame(width: 260)
  }

  private var wideSearchField: some View {
    searchField
      .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
  }

  private var compactSearchField: some View {
    searchField
      .frame(maxWidth: .infinity)
  }

  private var searchField: some View {
    TextField("搜索应用或主机名", text: $searchText)
      .textFieldStyle(.roundedBorder)
      .accessibilityLabel("搜索实时连接")
      .accessibilityHint("同时匹配当前 \(selectedRoute.title) 连接的应用名称和主机名")
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
    Table(connections) {
      TableColumn("主机名") { connection in
        let hostname = connection.metadata.hostname ?? ConnectionAttributionLabel.unknownHostname
        Text(hostname)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(hostname)
      }
      .width(min: 180, ideal: 280)

      TableColumn("应用") { connection in
        let applicationName =
          connection.metadata.applicationName ?? ConnectionAttributionLabel.unknownApplication
        Text(applicationName)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(applicationName)
      }
      .width(min: 140, ideal: 220)

      TableColumn("下载") { connection in
        rateText(connection.rate.downloadBytesPerSecond, color: MihomoColorToken.trafficDownload)
      }
      .width(min: 90, ideal: 100, max: 110)
      .alignment(.numeric)

      TableColumn("上传") { connection in
        rateText(connection.rate.uploadBytesPerSecond, color: MihomoColorToken.trafficUpload)
      }
      .width(min: 90, ideal: 100, max: 110)
      .alignment(.numeric)

      TableColumn("累计") { connection in
        Text(TrafficStatisticsFormatter.bytes(connection.cumulativeBytes.total))
          .monospacedDigit()
      }
      .width(min: 85, ideal: 100, max: 120)
      .alignment(.numeric)

      TableColumn("时长") { connection in
        Text(duration(connection))
          .monospacedDigit()
      }
      .width(min: 90, ideal: 105, max: 130)
      .alignment(.trailing)
    }
  }

  private var groupTable: some View {
    Table(groupRows) {
      TableColumn(selectedMode == .application ? "应用" : "域名") { row in
        Text(row.name)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(row.name)
      }
      .width(min: 220, ideal: 360)

      TableColumn(selectedMode == .application ? "域名数" : "应用数") { row in
        Text(row.relatedCount.formatted())
          .monospacedDigit()
      }
      .width(min: 72, ideal: 80, max: 90)
      .alignment(.numeric)

      TableColumn("连接数") { row in
        Text(row.connectionCount.formatted())
          .monospacedDigit()
      }
      .width(min: 72, ideal: 80, max: 90)
      .alignment(.numeric)

      TableColumn("下载") { row in
        rateText(row.rate.downloadBytesPerSecond, color: MihomoColorToken.trafficDownload)
      }
      .width(min: 90, ideal: 100, max: 110)
      .alignment(.numeric)

      TableColumn("上传") { row in
        rateText(row.rate.uploadBytesPerSecond, color: MihomoColorToken.trafficUpload)
      }
      .width(min: 90, ideal: 100, max: 110)
      .alignment(.numeric)

      TableColumn("活动累计") { row in
        Text(TrafficStatisticsFormatter.bytes(row.cumulativeBytes.total))
          .monospacedDigit()
      }
      .width(min: 95, ideal: 110, max: 130)
      .alignment(.numeric)
    }
  }

  private var displayedItemCount: Int {
    selectedMode == .connection ? connections.count : groupRows.count
  }

  private var normalizedSearchText: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var emptyTitle: String {
    normalizedSearchText.isEmpty
      ? "暂无 \(selectedRoute.title) 连接"
      : "没有匹配的实时连接"
  }

  private var emptyDescription: String {
    normalizedSearchText.isEmpty
      ? "连接出现后会在这里实时展示；消失后立即移除，不保留明细。"
      : "请尝试其他应用名称或主机名。"
  }

  private func rateText(_ bytesPerSecond: UInt64, color: Color) -> some View {
    Text(TrafficRateFormatter.string(from: bytesPerSecond))
      .monospacedDigit()
      .foregroundStyle(color)
  }

  private func duration(_ connection: LiveTrafficConnection) -> String {
    guard let startedAt = connection.startedAt else {
      return "—"
    }
    return TrafficStatisticsFormatter.duration(from: startedAt, to: Date())
  }
}
