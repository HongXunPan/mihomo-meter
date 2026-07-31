import SwiftUI

struct TrafficStatisticsSummaryView: View {
  @ObservedObject var controller: TrafficStatisticsController
  let isMonitoringAvailable: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Proxy 流量统计", systemImage: "stopwatch")
        .font(.headline)
      TrafficStatisticsNoticeView(
        controller: controller,
        isMonitoringAvailable: isMonitoringAvailable
      )
      TrafficStatisticsTotalsView(
        todayBytes: controller.snapshot.today.proxy.total,
        lifetimeBytes: controller.snapshot.lifetime.proxy.total
      )

      ProxyDailyTrafficChart(days: controller.snapshot.recentProxyDays)
    }
  }
}
