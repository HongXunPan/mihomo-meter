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
  private var statisticsController: TrafficStatisticsController?
  private var updateModel: AppUpdateModel?
  private var menuBarController: MenuBarController?
  private var isTerminationPending = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard ApplicationRuntimeEnvironment.current.shouldStartProductionServices else {
      return
    }

    NSApplication.shared.setActivationPolicy(.accessory)
    let statisticsController = TrafficStatisticsController(
      ledger: SQLiteTrafficLedger(
        databaseURL: TrafficLedgerLocation.defaultDatabaseURL()
      )
    )
    let monitor = TrafficMonitor(
      diagnosticLogger: DebugDiagnosticLogger.shared,
      statisticsRecorder: statisticsController
    )
    let updateModel = AppUpdateModel()
    trafficMonitor = monitor
    self.statisticsController = statisticsController
    self.updateModel = updateModel
    menuBarController = MenuBarController(
      monitor: monitor,
      statisticsController: statisticsController,
      updateModel: updateModel
    )
    updateModel.start()

    Task {
      #if DEBUG
        await DebugDiagnosticLogger.shared.record(
          .applicationLaunched(AppCodeSigningInspector.currentSummary())
        )
      #endif
      await statisticsController.prepare()
      monitor.start()
    }
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let trafficMonitor, let statisticsController else {
      return .terminateNow
    }
    guard !isTerminationPending else {
      return .terminateLater
    }
    isTerminationPending = true

    Task {
      await trafficMonitor.stopForApplicationTermination()
      await statisticsController.prepareForApplicationTermination()
      sender.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }
}
