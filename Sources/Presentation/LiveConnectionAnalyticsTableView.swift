import SwiftUI

struct LiveConnectionAnalyticsTableView: View {
  let selectedRoute: LiveConnectionRoute

  @Binding var selectedMode: LiveConnectionViewMode
  @Binding var searchText: String

  let connections: [LiveTrafficConnection]
  let groupRows: [LiveConnectionGroupRow]
  @State private var sortResetGeneration = 0

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
    .onChange(of: selectedMode) { _, _ in
      sortResetGeneration += 1
    }
    .onChange(of: selectedRoute) { _, _ in
      sortResetGeneration += 1
    }
  }

  private var tableToolbar: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        modePicker
        sortResetButton
        Spacer()
        wideSearchField
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 12) {
          modePicker
          sortResetButton
        }
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

  private var sortResetButton: some View {
    Button("恢复默认排序") {
      sortResetGeneration += 1
    }
    .help("恢复按总速度降序")
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
    LiveConnectionAppKitTableView(
      connections: connections,
      sortResetGeneration: sortResetGeneration
    )
  }

  private var groupTable: some View {
    LiveConnectionGroupAppKitTableView(
      mode: selectedMode,
      rows: groupRows,
      sortResetGeneration: sortResetGeneration
    )
    .id(selectedMode.rawValue)
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

}
