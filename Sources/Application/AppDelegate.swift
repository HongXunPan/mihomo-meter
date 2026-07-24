import AppKit

struct ApplicationRuntimeEnvironment: Sendable {
  private static let explicitTestModeKey = "MIHOMO_METER_TEST_MODE"
  private static let xCTestMarkerKeys = [
    "XCTestConfigurationFilePath",
    "XCTestBundlePath",
    "XCTestSessionIdentifier",
  ]

  let variables: [String: String]

  static var current: ApplicationRuntimeEnvironment {
    ApplicationRuntimeEnvironment(variables: ProcessInfo.processInfo.environment)
  }

  var shouldStartProductionServices: Bool {
    guard variables[Self.explicitTestModeKey] != "1" else {
      return false
    }
    return !Self.xCTestMarkerKeys.contains { variables[$0] != nil }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var trafficMonitor: TrafficMonitor?
  private var updateModel: AppUpdateModel?
  private var menuBarController: MenuBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard ApplicationRuntimeEnvironment.current.shouldStartProductionServices else {
      return
    }

    NSApplication.shared.setActivationPolicy(.accessory)
    let monitor = TrafficMonitor(
      diagnosticLogger: DebugDiagnosticLogger.shared
    )
    let updateModel = AppUpdateModel()
    trafficMonitor = monitor
    self.updateModel = updateModel
    menuBarController = MenuBarController(
      monitor: monitor,
      updateModel: updateModel
    )

    Task {
      #if DEBUG
        await DebugDiagnosticLogger.shared.record(
          .applicationLaunched(AppCodeSigningInspector.currentSummary())
        )
      #endif
      monitor.start()
      updateModel.checkForUpdates()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    trafficMonitor?.stopForApplicationTermination()
    updateModel?.cancel()
  }
}
