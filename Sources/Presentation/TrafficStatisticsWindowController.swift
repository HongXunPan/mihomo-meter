import AppKit
import SwiftUI

@MainActor
final class TrafficStatisticsWindowController: NSWindowController {
  private static let initialSize = NSSize(width: 960, height: 640)
  private static let minimumSize = NSSize(width: 820, height: 520)
  private static let frameAutosaveName = "TrafficStatisticsWindow"

  init(
    controller: TrafficStatisticsController,
    monitor: TrafficMonitor
  ) {
    let hostingController = NSHostingController(
      rootView: TrafficStatisticsView(
        controller: controller,
        monitor: monitor
      )
    )
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.initialSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Proxy 流量统计"
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

  func show() {
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)

    if #available(macOS 14.0, *) {
      NSApplication.shared.activate()
    } else {
      NSApplication.shared.activate(ignoringOtherApps: true)
    }
  }
}
