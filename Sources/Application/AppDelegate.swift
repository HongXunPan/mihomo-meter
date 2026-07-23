import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var menuBarController: MenuBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)
    menuBarController = MenuBarController()
  }
}
