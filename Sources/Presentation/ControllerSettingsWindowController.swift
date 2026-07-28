import AppKit
import SwiftUI

@MainActor
final class ControllerSettingsWindowController: NSWindowController {
  private static let initialSize = NSSize(width: 560, height: 380)
  private static let minimumSize = NSSize(width: 480, height: 320)
  private static let frameAutosaveName = "ControllerSettingsWindow"

  init(monitor: TrafficMonitor) {
    let hostingController = NSHostingController(
      rootView: ControllerSettingsView(monitor: monitor)
    )
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.initialSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Mihomo 连接"
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
    NSApplication.shared.activate()
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }
}
