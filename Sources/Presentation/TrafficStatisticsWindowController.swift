import AppKit
import SwiftUI

@MainActor
final class TrafficStatisticsWindowController: NSWindowController {
  private static let initialSize = NSSize(width: 1_080, height: 680)
  private static let minimumSize = NSSize(width: 900, height: 560)
  private static let frameAutosaveName = "TrafficStatisticsWindow"

  private let workspaceModel = StatisticsWorkspaceModel()
  private let connectionTrendWindowController: ConnectionAnalyticsTrendWindowController

  init(
    controller: TrafficStatisticsController,
    connectionAnalyticsController: ConnectionAnalyticsController,
    quotaController: RuntimeQuotaTrackingController,
    profileQuotaController: ProfileQuotaTrackingController,
    profileController: ClashProfileDirectoryController,
    subscriptionQuotaDataController: SubscriptionQuotaDataController,
    monitor: TrafficMonitor
  ) {
    let connectionTrendWindowController = ConnectionAnalyticsTrendWindowController(
      controller: connectionAnalyticsController
    )
    self.connectionTrendWindowController = connectionTrendWindowController
    let hostingController = NSHostingController(
      rootView: StatisticsWorkspaceView(
        model: workspaceModel,
        trafficController: controller,
        connectionAnalyticsController: connectionAnalyticsController,
        quotaController: quotaController,
        profileQuotaController: profileQuotaController,
        profileController: profileController,
        subscriptionQuotaDataController: subscriptionQuotaDataController,
        monitor: monitor,
        showConnectionTrend: { [weak connectionTrendWindowController] target in
          connectionTrendWindowController?.show(target: target)
        }
      )
    )
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.initialSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "统计"
    window.contentViewController = hostingController
    window.minSize = Self.minimumSize
    window.isReleasedWhenClosed = false
    window.tabbingMode = .disallowed
    window.center()
    window.setFrameAutosaveName(Self.frameAutosaveName)

    super.init(window: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func show(module: StatisticsModule) {
    if module == .proxyTraffic {
      workspaceModel.selectedProxyTrafficSection = .statistics
    }
    workspaceModel.selectedModule = module
    showCurrentModule()
  }

  func showCurrentModule() {
    NSApplication.shared.activate()
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }
}
