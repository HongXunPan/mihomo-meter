import AppKit
import SwiftUI

@MainActor
final class ConnectionAnalyticsTrendWindowController: NSWindowController, NSWindowDelegate {
  private static let initialSize = NSSize(width: 820, height: 560)
  private static let minimumSize = NSSize(width: 680, height: 460)
  private static let frameAutosaveName = "ConnectionAnalyticsTrendWindow"

  private let model: ConnectionAnalyticsTrendWindowModel
  private let dockVisibilityController: ApplicationDockVisibilityController

  init(
    controller: ConnectionAnalyticsController,
    dockVisibilityController: ApplicationDockVisibilityController
  ) {
    let model = ConnectionAnalyticsTrendWindowModel { query in
      try await controller.trend(query: query)
    }
    self.model = model
    self.dockVisibilityController = dockVisibilityController

    let hostingController = NSHostingController(
      rootView: ConnectionAnalyticsTrendView(model: model)
    )
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.initialSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "归因趋势"
    window.contentViewController = hostingController
    window.minSize = Self.minimumSize
    window.isReleasedWhenClosed = false
    window.tabbingMode = .disallowed
    window.center()
    window.setFrameAutosaveName(Self.frameAutosaveName)

    super.init(window: window)
    window.delegate = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func show(target: ConnectionAnalyticsTrendTarget) {
    window?.title = "\(target.dimension.title)趋势"
    model.show(target: target)
    dockVisibilityController.windowWillPresent(.connectionAnalyticsTrend)
    NSApplication.shared.activate()
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    model.reset()
    dockVisibilityController.windowWillClose(.connectionAnalyticsTrend)
  }
}
