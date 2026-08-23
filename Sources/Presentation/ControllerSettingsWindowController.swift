import AppKit
import SwiftUI

@MainActor
final class ControllerSettingsWindowController: NSWindowController, NSWindowDelegate {
  private static let initialSize = NSSize(width: 680, height: 640)
  private static let minimumSize = NSSize(width: 560, height: 480)
  private static let frameAutosaveName = "SettingsWindow"

  private let dockVisibilityController: ApplicationDockVisibilityController

  init(
    monitor: TrafficMonitor,
    updateModel: AppUpdateModel,
    launchAtLoginController: LaunchAtLoginController,
    systemNotificationController: SystemNotificationController,
    diagnosticExportController: DiagnosticExportController,
    dockVisibilityController: ApplicationDockVisibilityController
  ) {
    self.dockVisibilityController = dockVisibilityController
    let hostingController = NSHostingController(
      rootView: ControllerSettingsView(
        monitor: monitor,
        updateModel: updateModel,
        launchAtLoginController: launchAtLoginController,
        systemNotificationController: systemNotificationController,
        diagnosticExportController: diagnosticExportController
      )
    )
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.initialSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Mihomo Meter 设置"
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

  func show() {
    dockVisibilityController.windowWillPresent(.controllerSettings)
    NSApplication.shared.activate()
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    dockVisibilityController.windowWillClose(.controllerSettings)
  }
}
