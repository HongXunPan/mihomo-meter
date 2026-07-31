import AppKit
import SwiftUI

@MainActor
final class StatusMenuTrafficTasksMenuCoordinator {
  let contentViewController: NSHostingController<StatusMenuTrafficTasksView>

  init(
    controller: TrafficStatisticsController,
    isMonitoringAvailable: @escaping () -> Bool,
    showStatistics: @escaping () -> Void
  ) {
    contentViewController = NSHostingController(
      rootView: StatusMenuTrafficTasksView(
        controller: controller,
        isMonitoringAvailable: isMonitoringAvailable,
        showStatistics: showStatistics
      )
    )
    contentViewController.sizingOptions = []
    contentViewController.preferredContentSize = StatusMenuLayout.trafficTasksSubmenuSize
  }
}
