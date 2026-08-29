import SwiftUI

struct TrafficStatisticsView: View {
  @ObservedObject var controller: TrafficStatisticsController
  @ObservedObject var monitor: TrafficMonitor
  @Binding var selectedSection: ProxyTrafficSection
  @Binding var selectedLiveConnectionRoute: LiveConnectionRoute

  @State private var filter = TrafficStatisticsFilter.all
  @State private var editor: TrafficIntervalEditor?
  @State private var intervalPendingDeletion: TrafficInterval?
  @State private var showsClearConfirmation = false

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 20)
        .padding(.vertical, 16)

      Divider()

      Group {
        switch selectedSection {
        case .statistics:
          TrafficStatisticsTaskContentView(
            controller: controller,
            isMonitoringAvailable: isMonitoringAvailable,
            filter: $filter,
            editor: $editor,
            intervalPendingDeletion: $intervalPendingDeletion
          )
        case .liveConnections:
          LiveConnectionAnalyticsView(
            monitor: monitor,
            selectedRoute: $selectedLiveConnectionRoute
          )
        }
      }
      .padding(20)
    }
    .frame(minWidth: 760, minHeight: 560)
    .confirmationDialog(
      "清空本地统计？",
      isPresented: $showsClearConfirmation
    ) {
      Button("清空", role: .destructive) {
        Task {
          await controller.clear()
          guard controller.operationMessage == nil else {
            return
          }
          editor = nil
          intervalPendingDeletion = nil
        }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("核心流量账本、全部统计任务和连接归因历史会被删除；服务地址与访问密钥（Secret）会保留。")
    }
  }

  private var header: some View {
    ViewThatFits(in: .horizontal) {
      wideHeader
      compactHeader
    }
  }

  private var wideHeader: some View {
    HStack(alignment: .center, spacing: 12) {
      headerTitle
        .fixedSize(horizontal: true, vertical: false)

      Spacer()

      headerControls
    }
  }

  private var compactHeader: some View {
    VStack(alignment: .leading, spacing: 12) {
      headerTitle

      HStack(spacing: 12) {
        sectionPicker
        Spacer()
        statisticsActions
      }
    }
  }

  private var headerTitle: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text("Proxy 流量")
        .font(.title2.weight(.semibold))
      Text(headerSubtitle)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var headerControls: some View {
    HStack(spacing: 12) {
      sectionPicker
      statisticsActions
    }
  }

  @ViewBuilder
  private var statisticsActions: some View {
    if selectedSection == .statistics {
      Button("开始统计") {
        intervalPendingDeletion = nil
        editor = .create(initialName: suggestedName)
      }
      .buttonStyle(.borderedProminent)
      .disabled(!canStartInterval)

      Menu {
        Button("清空本地统计", role: .destructive) {
          showsClearConfirmation = true
        }
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .accessibilityLabel("更多统计操作")
    }
  }

  private var sectionPicker: some View {
    Picker("Proxy 流量范围", selection: $selectedSection) {
      ForEach(ProxyTrafficSection.allCases) { section in
        Text(section.title).tag(section)
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .frame(width: 280)
  }

  private var headerSubtitle: String {
    switch selectedSection {
    case .statistics:
      "管理秒表式统计任务，并查看本机 Proxy 累计。"
    case .liveConnections:
      "查看当前 Proxy 与 DIRECT 连接的速率、累计和识别信息。"
    }
  }

  private var isMonitoringAvailable: Bool {
    switch monitor.connectionState {
    case .connected, .stale, .reconnecting:
      true
    case .disconnected, .connecting, .authenticationFailed, .unsupported:
      false
    }
  }

  private var canStartInterval: Bool {
    controller.availability.isAvailable && isMonitoringAvailable && editor == nil
  }

  private var suggestedName: String {
    TrafficStatisticsPresentation.suggestedIntervalName(from: controller.snapshot.intervals)
  }
}

enum ProxyTrafficSection: String, CaseIterable, Identifiable {
  case statistics
  case liveConnections

  var id: Self {
    self
  }

  var title: String {
    switch self {
    case .statistics:
      "流量统计"
    case .liveConnections:
      "实时连接"
    }
  }
}

struct TrafficIntervalEditor: Identifiable {
  enum Kind {
    case create
    case rename(TrafficInterval)
  }

  let kind: Kind
  var draftName: String

  static func create(initialName: String) -> TrafficIntervalEditor {
    TrafficIntervalEditor(kind: .create, draftName: initialName)
  }

  static func rename(_ interval: TrafficInterval) -> TrafficIntervalEditor {
    TrafficIntervalEditor(kind: .rename(interval), draftName: interval.name)
  }

  var id: String {
    switch kind {
    case .create:
      return "create"
    case .rename(let interval):
      return "rename-\(interval.id.uuidString)"
    }
  }
}
