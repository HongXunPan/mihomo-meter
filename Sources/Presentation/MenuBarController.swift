import AppKit
import Combine

struct MenuBarPresentationActions {
  let showStatistics: (StatisticsModule) -> Void
  let showLiveConnections: (LiveConnectionRoute) -> Void
  let showControllerSettings: () -> Void
}

@MainActor
final class MenuBarController: NSObject {
  private static let statusItemLength: CGFloat = 66
  private static let statusContentHeight: CGFloat = 20

  private let statusItem: NSStatusItem
  private let statusContentView: ProxyStatusItemView
  private let monitor: TrafficMonitor
  private let statisticsController: TrafficStatisticsController
  private let quotaController: RuntimeQuotaTrackingController
  private let profileQuotaController: ProfileQuotaTrackingController
  private let updateModel: AppUpdateModel
  private let actions: MenuBarPresentationActions
  private let helpMenuController: AppHelpMenuController
  private var updateMenuItem: NSMenuItem?
  private var cancellables: Set<AnyCancellable> = []

  private lazy var statusMenuController = makeStatusMenuController()

  init(
    monitor: TrafficMonitor,
    statisticsController: TrafficStatisticsController,
    quotaController: RuntimeQuotaTrackingController,
    profileQuotaController: ProfileQuotaTrackingController,
    updateModel: AppUpdateModel,
    actions: MenuBarPresentationActions
  ) {
    statusItem = NSStatusBar.system.statusItem(
      withLength: MenuBarController.statusItemLength
    )
    statusContentView = ProxyStatusItemView()
    self.monitor = monitor
    self.statisticsController = statisticsController
    self.quotaController = quotaController
    self.profileQuotaController = profileQuotaController
    self.updateModel = updateModel
    self.actions = actions
    helpMenuController = AppHelpMenuController()
    super.init()

    configureStatusItem()
    statusItem.menu = statusMenuController.menu
    observeMonitor()
    observeStatistics()
    observeUpdateAvailability()
  }

  private func configureStatusItem() {
    guard let button = statusItem.button else {
      return
    }

    button.title = ""
    button.setAccessibilityLabel("Mihomo Meter")

    statusContentView.translatesAutoresizingMaskIntoConstraints = false
    button.addSubview(statusContentView)
    NSLayoutConstraint.activate([
      statusContentView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 4),
      statusContentView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
      statusContentView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
      statusContentView.heightAnchor.constraint(equalToConstant: Self.statusContentHeight),
    ])

    updateStatusItemButton(button, rate: .zero, state: monitor.connectionState)
  }

  private func makeStatusMenuController() -> StatusMenuController {
    let factory = StatusMenuFactory(
      monitor: monitor,
      statisticsController: statisticsController,
      quotaController: quotaController,
      profileQuotaController: profileQuotaController
    )
    let controller = factory.makeController(
      showControllerSettings: { [weak self] in
        self?.performMenuAction {
          self?.actions.showControllerSettings()
        }
      },
      showTrafficStatistics: { [weak self] in
        self?.showProxyTrafficStatistics()
      },
      showLiveConnections: { [weak self] route in
        self?.performMenuAction {
          self?.actions.showLiveConnections(route)
        }
      },
      proxyTrafficNavigationItem: makeProxyTrafficNavigationItem(),
      subscriptionQuotaNavigationItem: makeSubscriptionQuotaNavigationItem()
    )
    appendNativeActions(to: controller.menu)
    return controller
  }

  private func makeProxyTrafficNavigationItem() -> NSMenuItem {
    let item = NSMenuItem(
      title: "查看 Proxy 流量统计",
      action: #selector(showProxyTrafficStatistics),
      keyEquivalent: ""
    )
    item.target = self
    return item
  }

  private func makeSubscriptionQuotaNavigationItem() -> NSMenuItem {
    let item = NSMenuItem(
      title: "查看订阅余额统计",
      action: #selector(showSubscriptionQuotaStatistics),
      keyEquivalent: ""
    )
    item.target = self
    return item
  }

  private func appendNativeActions(to menu: NSMenu) {
    menu.addItem(.separator())

    let connectionAnalyticsItem = NSMenuItem(
      title: "连接分析…",
      action: #selector(showConnectionAnalytics),
      keyEquivalent: ""
    )
    connectionAnalyticsItem.target = self
    menu.addItem(connectionAnalyticsItem)

    let settingsItem = NSMenuItem(
      title: "设置…",
      action: #selector(showControllerSettings),
      keyEquivalent: ","
    )
    settingsItem.target = self
    settingsItem.keyEquivalentModifierMask = [.command]
    menu.addItem(settingsItem)

    menu.addItem(helpMenuController.menuItem)

    let updateItem = NSMenuItem(
      title: "检查更新…",
      action: #selector(checkForUpdates),
      keyEquivalent: ""
    )
    updateItem.target = self
    updateItem.isEnabled = updateModel.canCheckForUpdates
    updateMenuItem = updateItem
    menu.addItem(updateItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: "退出 Mihomo Meter",
      action: #selector(terminateApplication),
      keyEquivalent: "q"
    )
    quitItem.target = self
    quitItem.keyEquivalentModifierMask = [.command]
    menu.addItem(quitItem)
  }

  private func observeMonitor() {
    monitor.statusItemPublisher
      .sink { [weak self] snapshot in
        guard let self, let button = self.statusItem.button else {
          return
        }

        self.updateStatusItemButton(
          button,
          rate: snapshot.rate,
          state: snapshot.connectionState
        )
      }
      .store(in: &cancellables)

    monitor.objectWillChange
      .sink { [weak self] in
        Task { @MainActor [weak self] in
          await Task.yield()
          self?.statusMenuController.refreshSummaries()
        }
      }
      .store(in: &cancellables)
  }

  private func observeUpdateAvailability() {
    updateModel.$canCheckForUpdates
      .removeDuplicates()
      .sink { [weak self] canCheckForUpdates in
        self?.updateMenuItem?.isEnabled = canCheckForUpdates
      }
      .store(in: &cancellables)
  }

  private func observeStatistics() {
    statisticsController.$snapshot
      .map { snapshot in
        snapshot.intervals.count { $0.status == .active }
      }
      .removeDuplicates()
      .sink { [weak self] _ in
        self?.statusMenuController.refreshSummaries()
      }
      .store(in: &cancellables)
  }

  private func updateStatusItemButton(
    _ button: NSStatusBarButton,
    rate: TrafficRate,
    state: MonitorConnectionState
  ) {
    statusContentView.update(rate: rate, state: state)

    guard state == .connected else {
      button.toolTip = "Mihomo Meter · \(state.title)"
      button.setAccessibilityValue(state.title)
      return
    }

    let summary =
      "Proxy 下载 \(TrafficRateFormatter.string(from: rate.downloadBytesPerSecond))，"
      + "上传 \(TrafficRateFormatter.string(from: rate.uploadBytesPerSecond))"
    button.toolTip = "Mihomo Meter · \(state.title)\n\(summary)"
    button.setAccessibilityValue("\(state.title)，\(summary)")
  }

  private func performMenuAction(_ action: () -> Void) {
    statusMenuController.close()
    action()
  }

  @objc
  private func showControllerSettings() {
    performMenuAction {
      actions.showControllerSettings()
    }
  }

  @objc
  private func showProxyTrafficStatistics() {
    performMenuAction {
      actions.showStatistics(.proxyTraffic)
    }
  }

  @objc
  private func showSubscriptionQuotaStatistics() {
    performMenuAction {
      actions.showStatistics(.subscriptionQuota)
    }
  }

  @objc
  private func showConnectionAnalytics() {
    performMenuAction {
      actions.showStatistics(.connectionAnalytics)
    }
  }

  @objc
  private func checkForUpdates() {
    performMenuAction {
      NSApplication.shared.activate()
      updateModel.checkForUpdates()
    }
  }

  @objc
  private func terminateApplication() {
    NSApplication.shared.terminate(nil)
  }

  func dismissStatusMenuForWindowPresentation() {
    statusMenuController.close()
  }
}
