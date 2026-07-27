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
  private var quotaController: RuntimeQuotaTrackingController?
  private var profileQuotaController: ProfileQuotaTrackingController?
  private var profileDirectoryController: ClashProfileDirectoryController?
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
    let mihomoClient = MihomoControllerClient()
    let quotaLedger = SQLiteQuotaLedger(
      databaseURL: QuotaLedgerLocation.defaultDatabaseURL()
    )
    let quotaController = RuntimeQuotaTrackingController(
      ledger: quotaLedger,
      observer: RuntimeQuotaObservationCoordinator(client: mihomoClient)
    )
    let profileQuotaController = ProfileQuotaTrackingController(
      ledger: quotaLedger,
      diagnosticLogger: AppDiagnosticLogger.shared
    )
    let profileDirectoryController = ClashProfileDirectoryController(
      authorizer: SystemProfileDirectoryAuthorizer(),
      bookmarkStore: UserDefaultsProfileDirectoryBookmarkStore(userDefaults: .standard),
      securityScope: SystemProfileDirectorySecurityScope(),
      reader: YAMLClashProfileCatalogReader(),
      observer: ProfileDirectoryObserver(),
      trackingService: ClashProfileTrackingService(
        ledger: quotaLedger,
        fingerprinter: HMACProfileURLFingerprinter(
          keyStore: KeychainProfileFingerprintKeyStore()
        )
      ),
      profileQuotaLifecycle: profileQuotaController
    )
    let monitor = TrafficMonitor(
      client: mihomoClient,
      diagnosticLogger: AppDiagnosticLogger.shared,
      statisticsRecorder: statisticsController,
      runtimeQuotaLifecycle: quotaController,
      profileQuotaLifecycle: profileQuotaController
    )
    let updateModel = AppUpdateModel()
    trafficMonitor = monitor
    self.statisticsController = statisticsController
    self.quotaController = quotaController
    self.profileQuotaController = profileQuotaController
    self.profileDirectoryController = profileDirectoryController
    self.updateModel = updateModel
    menuBarController = MenuBarController(
      monitor: monitor,
      statisticsController: statisticsController,
      quotaController: quotaController,
      profileQuotaController: profileQuotaController,
      profileController: profileDirectoryController,
      updateModel: updateModel
    )
    updateModel.start()

    Task {
      await AppDiagnosticLogger.shared.record(
        .applicationLaunched(AppCodeSigningInspector.currentSummary())
      )
      await statisticsController.prepare()
      await quotaController.prepare()
      await profileQuotaController.prepare()
      await profileDirectoryController.prepare()
      monitor.start()
    }
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard
      let trafficMonitor,
      let statisticsController,
      let quotaController,
      let profileQuotaController,
      let profileDirectoryController
    else {
      return .terminateNow
    }
    guard !isTerminationPending else {
      return .terminateLater
    }
    isTerminationPending = true

    Task {
      quotaController.stop()
      profileQuotaController.stop()
      profileDirectoryController.stop()
      await trafficMonitor.stopForApplicationTermination()
      await statisticsController.prepareForApplicationTermination()
      sender.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }
}
