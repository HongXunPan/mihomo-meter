import AppKit
import SwiftUI

@MainActor
final class TrafficStatisticsWindowController: NSWindowController {
  private static let initialSize = NSSize(width: 1_080, height: 680)
  private static let minimumSize = NSSize(width: 900, height: 560)
  private static let frameAutosaveName = "TrafficStatisticsWindow"

  private let workspaceModel = StatisticsWorkspaceModel()

  init(
    controller: TrafficStatisticsController,
    quotaController: RuntimeQuotaTrackingController,
    monitor: TrafficMonitor
  ) {
    let hostingController = NSHostingController(
      rootView: StatisticsWorkspaceView(
        model: workspaceModel,
        trafficController: controller,
        quotaController: quotaController,
        monitor: monitor
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
    workspaceModel.selectedModule = module
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)

    if #available(macOS 14.0, *) {
      NSApplication.shared.activate()
    } else {
      NSApplication.shared.activate(ignoringOtherApps: true)
    }
  }
}
