import AppKit

@MainActor
final class AppPresentationCoordinator {
  struct Dependencies {
    let monitor: TrafficMonitor
    let statisticsController: TrafficStatisticsController
    let quotaController: RuntimeQuotaTrackingController
    let profileQuotaController: ProfileQuotaTrackingController
    let profileController: ClashProfileDirectoryController
    let subscriptionQuotaDataController: SubscriptionQuotaDataController
    let updateModel: AppUpdateModel
  }

  private let dependencies: Dependencies
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
      startTrafficStatistics: { [weak self] in
        self?.showTrafficIntervalCreation()
      },
      showControllerSettings: { [weak self] in
        self?.showControllerSettings()
      }
    )
  )

  init(dependencies: Dependencies) {
    self.dependencies = dependencies
    statisticsWindowController = TrafficStatisticsWindowController(
      controller: dependencies.statisticsController,
      quotaController: dependencies.quotaController,
      profileQuotaController: dependencies.profileQuotaController,
      profileController: dependencies.profileController,
      subscriptionQuotaDataController: dependencies.subscriptionQuotaDataController,
      monitor: dependencies.monitor
    )
    controllerSettingsWindowController = ControllerSettingsWindowController(
      monitor: dependencies.monitor
    )

    // 状态栏必须随应用协调器一起完成装配并保持整个应用生命周期。
    _ = menuBarController
  }

  func showCurrentStatisticsWindow() {
    menuBarController.dismissStatusMenuForWindowPresentation()
    statisticsWindowController.showCurrentModule()
  }

  private func showStatisticsWindow(module: StatisticsModule) {
    menuBarController.dismissStatusMenuForWindowPresentation()
    statisticsWindowController.show(module: module)
  }

  private func showTrafficIntervalCreation() {
    menuBarController.dismissStatusMenuForWindowPresentation()
    statisticsWindowController.showTrafficIntervalCreation()
  }

  private func showControllerSettings() {
    menuBarController.dismissStatusMenuForWindowPresentation()
    controllerSettingsWindowController.show()
  }
}
