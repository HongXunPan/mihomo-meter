import AppKit

@MainActor
final class AppPresentationCoordinator {
  struct Dependencies {
    let monitor: TrafficMonitor
    let statisticsController: TrafficStatisticsController
    let connectionAnalyticsController: ConnectionAnalyticsController
    let quotaController: RuntimeQuotaTrackingController
    let profileQuotaController: ProfileQuotaTrackingController
    let profileController: ClashProfileDirectoryController
    let subscriptionQuotaDataController: SubscriptionQuotaDataController
    let updateModel: AppUpdateModel
  }

  private let dependencies: Dependencies
  private let dockVisibilityController: ApplicationDockVisibilityController
  private let statisticsWindowController: TrafficStatisticsWindowController
  private let controllerSettingsWindowController: ControllerSettingsWindowController

  private lazy var menuBarController = MenuBarController(
    monitor: dependencies.monitor,
    statisticsController: dependencies.statisticsController,
    quotaController: dependencies.quotaController,
    profileQuotaController: dependencies.profileQuotaController,
    updateModel: dependencies.updateModel,
    actions: MenuBarPresentationActions(
      showStatistics: { [weak self] module in
        self?.showStatisticsWindow(module: module)
      },
      showControllerSettings: { [weak self] in
        self?.showControllerSettings()
      }
    )
  )

  init(dependencies: Dependencies) {
    self.dependencies = dependencies
    let dockVisibilityController = ApplicationDockVisibilityController()
    self.dockVisibilityController = dockVisibilityController
    statisticsWindowController = TrafficStatisticsWindowController(
      controller: dependencies.statisticsController,
      connectionAnalyticsController: dependencies.connectionAnalyticsController,
      quotaController: dependencies.quotaController,
      profileQuotaController: dependencies.profileQuotaController,
      profileController: dependencies.profileController,
      subscriptionQuotaDataController: dependencies.subscriptionQuotaDataController,
      monitor: dependencies.monitor,
      dockVisibilityController: dockVisibilityController
    )
    controllerSettingsWindowController = ControllerSettingsWindowController(
      monitor: dependencies.monitor,
      updateModel: dependencies.updateModel,
      dockVisibilityController: dockVisibilityController
    )

    // 状态栏必须随应用协调器一起完成装配并保持整个应用生命周期。
    _ = menuBarController
  }

  func showCurrentStatisticsWindow() {
    menuBarController.dismissStatusMenuForWindowPresentation()
    statisticsWindowController.showCurrentModule()
  }

  func showControllerSettings() {
    menuBarController.dismissStatusMenuForWindowPresentation()
    controllerSettingsWindowController.show()
  }

  private func showStatisticsWindow(module: StatisticsModule) {
    menuBarController.dismissStatusMenuForWindowPresentation()
    statisticsWindowController.show(module: module)
  }
}
