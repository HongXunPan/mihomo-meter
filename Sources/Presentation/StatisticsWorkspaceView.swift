import SwiftUI

enum StatisticsModule: String, CaseIterable, Identifiable, Hashable {
  case proxyTraffic
  case subscriptionQuota

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .proxyTraffic:
      "Proxy 流量"
    case .subscriptionQuota:
      "订阅余额"
    }
  }

  var symbolName: String {
    switch self {
    case .proxyTraffic:
      "chart.bar.xaxis"
    case .subscriptionQuota:
      "chart.line.downtrend.xyaxis"
    }
  }
}

@MainActor
final class StatisticsWorkspaceModel: ObservableObject {
  @Published var selectedModule = StatisticsModule.proxyTraffic
}

struct StatisticsWorkspaceView: View {
  @ObservedObject var model: StatisticsWorkspaceModel
  @ObservedObject var trafficController: TrafficStatisticsController
  @ObservedObject var quotaController: RuntimeQuotaTrackingController
  @ObservedObject var profileQuotaController: ProfileQuotaTrackingController
  @ObservedObject var profileController: ClashProfileDirectoryController
  @ObservedObject var monitor: TrafficMonitor

  var body: some View {
    NavigationSplitView {
      List(StatisticsModule.allCases, selection: $model.selectedModule) { module in
        Label(module.title, systemImage: module.symbolName)
          .tag(module)
      }
      .navigationTitle("统计")
      .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
    } detail: {
      switch model.selectedModule {
      case .proxyTraffic:
        TrafficStatisticsView(
          controller: trafficController,
          monitor: monitor
        )
      case .subscriptionQuota:
        SubscriptionQuotaStatisticsView(
          controller: quotaController,
          profileQuotaController: profileQuotaController,
          profileController: profileController
        )
      }
    }
  }
}
