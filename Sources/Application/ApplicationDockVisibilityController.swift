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
  private var presentedWindows: Set<ManagedWindow> = []

  convenience init() {
    self.init(application: NSApplication.shared)
  }

  init(application: ApplicationActivationPolicyControlling) {
    self.application = application
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

    let didApplyPolicy = application.setActivationPolicy(targetPolicy)
    assert(didApplyPolicy, "无法切换 Mihomo Meter 的应用激活策略")
  }
}
