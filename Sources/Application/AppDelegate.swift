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
  private var systemNotificationController: SystemNotificationController?
  private var systemRecoveryController: SystemRecoveryController?
  private var userNotificationClient: UserNotificationClient?
  private var presentationCoordinator: AppPresentationCoordinator?
  private var pendingActivationTarget: AppActivationTarget?
  private var launchSessionObservers: [NSObjectProtocol] = []
  private var launchSessionIsInactive = false
  private var isTerminationPending = false

  func applicationWillFinishLaunching(_ notification: Notification) {
    guard ApplicationRuntimeEnvironment.current.shouldStartProductionServices else {
      return
    }

    let center = NSWorkspace.shared.notificationCenter
    launchSessionObservers = [
      center.addObserver(
        forName: NSWorkspace.sessionDidResignActiveNotification,
        object: NSWorkspace.shared,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.launchSessionIsInactive = true
        }
      },
      center.addObserver(
        forName: NSWorkspace.sessionDidBecomeActiveNotification,
        object: NSWorkspace.shared,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.launchSessionIsInactive = false
        }
      },
    ]
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard ApplicationRuntimeEnvironment.current.shouldStartProductionServices else {
      return
    }

    SharedCoreTrafficShadow.configure(
      reporter: SharedCoreTrafficDiagnosticReporter.reportShadow
    )
    SharedCoreProxyTypeShadow.configure(
      reporter: SharedCoreTrafficDiagnosticReporter.reportProxyTypeShadow
    )
    SharedCoreProxyTypeRoute.configure(
      reporter: SharedCoreTrafficDiagnosticReporter.reportProxyTypeRoute
    )
    SharedCoreTrafficRoute.configure(
      reporter: SharedCoreTrafficDiagnosticReporter.reportRoute
    )
    let sharedCoreRuntimeStatus = SharedCoreRuntimeProbe.run()
    let trafficLedger = SQLiteTrafficLedger(
      databaseURL: TrafficLedgerLocation.defaultDatabaseURL()
    )
    let connectionAnalyticsController = ConnectionAnalyticsController(
      ledger: SQLiteConnectionAnalyticsLedger(
        databaseURL: ConnectionAnalyticsLedgerLocation.defaultDatabaseURL()
      ),
      proxyDailyTraffic: trafficLedger
    )
    let statisticsController = TrafficStatisticsController(
      ledger: trafficLedger,
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
    let userNotificationClient = UserNotificationClient()
    let systemNotificationController = SystemNotificationController(
      runtimeController: quotaController,
      profileController: profileQuotaController,
      monitor: monitor,
      client: userNotificationClient
    )
    let systemRecoveryController = SystemRecoveryController(monitor: monitor)
    trafficMonitor = monitor
    self.statisticsController = statisticsController
    self.connectionAnalyticsController = connectionAnalyticsController
    self.quotaController = quotaController
    self.profileQuotaController = profileQuotaController
    self.profileDirectoryController = profileDirectoryController
    self.subscriptionQuotaDataController = subscriptionQuotaDataController
    self.updateModel = updateModel
    self.systemNotificationController = systemNotificationController
    self.systemRecoveryController = systemRecoveryController
    self.userNotificationClient = userNotificationClient
    let presentationCoordinator = AppPresentationCoordinator(
      dependencies: AppPresentationCoordinator.Dependencies(
        monitor: monitor,
        statisticsController: statisticsController,
        connectionAnalyticsController: connectionAnalyticsController,
        quotaController: quotaController,
        profileQuotaController: profileQuotaController,
        profileController: profileDirectoryController,
        subscriptionQuotaDataController: subscriptionQuotaDataController,
        updateModel: updateModel,
        systemNotificationController: systemNotificationController
      )
    )
    self.presentationCoordinator = presentationCoordinator
    userNotificationClient.activationHandler = { [weak presentationCoordinator] target in
      presentationCoordinator?.activate(target)
    }
    if let pendingActivationTarget {
      self.pendingActivationTarget = nil
      presentationCoordinator.activate(pendingActivationTarget)
    }
    systemRecoveryController.start(initialSessionIsInactive: launchSessionIsInactive)
    stopLaunchSessionObservation()
    updateModel.start()

    Task {
      await AppDiagnosticLogger.shared.record(
        .applicationLaunched(AppCodeSigningInspector.currentSummary())
      )
      await AppDiagnosticLogger.shared.record(
        .sharedCoreRuntimeProbe(sharedCoreRuntimeStatus)
      )
      await statisticsController.prepare()
      await connectionAnalyticsController.prepare()
      await quotaController.prepare()
      await profileQuotaController.prepare()
      await profileDirectoryController.prepare()
      systemNotificationController.start()
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

  func application(_: NSApplication, open urls: [URL]) {
    let target = urls.count == 1 ? AppDeepLink.target(for: urls[0]) : nil
    activateExternalTarget(target ?? AppDeepLink.fallbackTarget)
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
      let profileDirectoryController,
      let systemNotificationController,
      let systemRecoveryController
    else {
      return .terminateNow
    }
    guard !isTerminationPending else {
      return .terminateLater
    }
    isTerminationPending = true

    Task {
      systemNotificationController.stop()
      systemRecoveryController.stop()
      quotaController.stop()
      profileQuotaController.stop()
      profileDirectoryController.stop()
      await trafficMonitor.stopForApplicationTermination()
      await statisticsController.prepareForApplicationTermination()
      sender.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }

  private func stopLaunchSessionObservation() {
    let center = NSWorkspace.shared.notificationCenter
    launchSessionObservers.forEach(center.removeObserver)
    launchSessionObservers.removeAll()
  }

  private func activateExternalTarget(_ target: AppActivationTarget) {
    guard let presentationCoordinator else {
      pendingActivationTarget = target
      return
    }
    presentationCoordinator.activate(target)
  }
}
