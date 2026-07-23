import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var trafficMonitor: TrafficMonitor?
  private var menuBarController: MenuBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)
    let monitor = TrafficMonitor()
    trafficMonitor = monitor
    menuBarController = MenuBarController(monitor: monitor)
    monitor.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    trafficMonitor?.disconnect()
  }
}
