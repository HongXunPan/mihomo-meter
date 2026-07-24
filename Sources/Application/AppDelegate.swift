import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var trafficMonitor: TrafficMonitor?
  private var menuBarController: MenuBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)
    let monitor = TrafficMonitor(
      diagnosticLogger: DebugDiagnosticLogger.shared
    )
    trafficMonitor = monitor
    menuBarController = MenuBarController(monitor: monitor)

    Task {
      #if DEBUG
        await DebugDiagnosticLogger.shared.record(
          .applicationLaunched(AppCodeSigningInspector.currentSummary())
        )
      #endif
      monitor.start()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    trafficMonitor?.stopForApplicationTermination()
  }
}
