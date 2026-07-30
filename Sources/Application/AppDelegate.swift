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
  private var connectionAnalyticsController: ConnectionAnalyticsController?
  private var quotaController: RuntimeQuotaTrackingController?
  private var profileQuotaController: ProfileQuotaTrackingController?
  private var profileDirectoryController: ClashProfileDirectoryController?
  private var subscriptionQuotaDataController: SubscriptionQuotaDataController?
  private var updateModel: AppUpdateModel?
  private var presentationCoordinator: AppPresentationCoordinator?
  private var isTerminationPending = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard ApplicationRuntimeEnvironment.current.shouldStartProductionServices else {
      return
    }

    let connectionAnalyticsController = ConnectionAnalyticsController(
      ledger: SQLiteConnectionAnalyticsLedger(
        databaseURL: ConnectionAnalyticsLedgerLocation.defaultDatabaseURL()
      )
    )
    let statisticsController = TrafficStatisticsController(
      ledger: SQLiteTrafficLedger(
        databaseURL: TrafficLedgerLocation.defaultDatabaseURL()
      ),
      connectionAnalyticsHistory: connectionAnalyticsController
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
    let subscriptionQuotaDataController = SubscriptionQuotaDataController(
      ledger: quotaLedger,
      runtimeController: quotaController,
      profileQuotaController: profileQuotaController,
      profileDirectoryController: profileDirectoryController
    )
    let monitor = TrafficMonitor(
      client: mihomoClient,
      diagnosticLogger: AppDiagnosticLogger.shared,
      statisticsRecorder: statisticsController,
      connectionAnalyticsRecorder: connectionAnalyticsController,
      runtimeQuotaLifecycle: quotaController,
      profileQuotaLifecycle: profileQuotaController
    )
    let updateModel = AppUpdateModel()
    trafficMonitor = monitor
    self.statisticsController = statisticsController
    self.connectionAnalyticsController = connectionAnalyticsController
    self.quotaController = quotaController
    self.profileQuotaController = profileQuotaController
    self.profileDirectoryController = profileDirectoryController
    self.subscriptionQuotaDataController = subscriptionQuotaDataController
    self.updateModel = updateModel
    let presentationCoordinator = AppPresentationCoordinator(
      dependencies: AppPresentationCoordinator.Dependencies(
        monitor: monitor,
        statisticsController: statisticsController,
        connectionAnalyticsController: connectionAnalyticsController,
        quotaController: quotaController,
        profileQuotaController: profileQuotaController,
        profileController: profileDirectoryController,
        subscriptionQuotaDataController: subscriptionQuotaDataController,
        updateModel: updateModel
      )
    )
    self.presentationCoordinator = presentationCoordinator
    updateModel.start()

    Task {
      await AppDiagnosticLogger.shared.record(
        .applicationLaunched(AppCodeSigningInspector.currentSummary())
      )
      await statisticsController.prepare()
      await connectionAnalyticsController.prepare()
      await quotaController.prepare()
      await profileQuotaController.prepare()
      await profileDirectoryController.prepare()
      monitor.start()
    }
  }

  func applicationShouldHandleReopen(
    _: NSApplication,
    hasVisibleWindows _: Bool
  ) -> Bool {
    presentationCoordinator?.showCurrentStatisticsWindow()
    return true
  }

  func showControllerSettings() {
    presentationCoordinator?.showControllerSettings()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
    false
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
