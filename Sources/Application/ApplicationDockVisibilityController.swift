import AppKit

@MainActor
protocol ApplicationActivationPolicyControlling: AnyObject {
  func activationPolicy() -> NSApplication.ActivationPolicy
  func setActivationPolicy(_ activationPolicy: NSApplication.ActivationPolicy) -> Bool
}

extension NSApplication: ApplicationActivationPolicyControlling {}

@MainActor
final class ApplicationDockVisibilityController {
  enum ManagedWindow: Hashable {
    case statistics
    case controllerSettings
    case connectionAnalyticsTrend
  }

  private let application: ApplicationActivationPolicyControlling
  private let dockIconRefresher: () -> Void
  private var presentedWindows: Set<ManagedWindow> = []

  convenience init() {
    self.init(
      application: NSApplication.shared,
      dockIconRefresher: Self.refreshDockIcon
    )
  }

  init(
    application: ApplicationActivationPolicyControlling,
    dockIconRefresher: @escaping () -> Void = {}
  ) {
    self.application = application
    self.dockIconRefresher = dockIconRefresher
    applyActivationPolicy()
  }

  func windowWillPresent(_ window: ManagedWindow) {
    presentedWindows.insert(window)
    applyActivationPolicy()
  }

  func windowWillClose(_ window: ManagedWindow) {
    presentedWindows.remove(window)
    applyActivationPolicy()
  }

  private func applyActivationPolicy() {
    let targetPolicy: NSApplication.ActivationPolicy =
      presentedWindows.isEmpty ? .accessory : .regular
    guard application.activationPolicy() != targetPolicy else {
      return
    }

    guard application.setActivationPolicy(targetPolicy) else {
      assertionFailure("无法切换 Mihomo Meter 的应用激活策略")
      return
    }
    if targetPolicy == .regular {
      dockIconRefresher()
    }
  }

  private static func refreshDockIcon() {
    guard
      let iconFile = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String
    else {
      return
    }

    let iconFileURL = URL(fileURLWithPath: iconFile)
    let resourceName = iconFileURL.deletingPathExtension().lastPathComponent
    let resourceExtension = iconFileURL.pathExtension.isEmpty ? "icns" : iconFileURL.pathExtension
    guard
      let iconURL = Bundle.main.url(
        forResource: resourceName,
        withExtension: resourceExtension
      ),
      let iconImage = NSImage(contentsOf: iconURL)
    else {
      return
    }

    NSApplication.shared.applicationIconImage = iconImage
    NSApplication.shared.dockTile.display()
  }
}
