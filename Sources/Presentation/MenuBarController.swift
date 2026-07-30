import AppKit
import Combine
import SwiftUI

struct MenuBarPresentationActions {
  let showStatistics: (StatisticsModule) -> Void
  let showControllerSettings: () -> Void
}

@MainActor
final class MenuBarController: NSObject {
  private static let statusItemLength: CGFloat = 58
  private static let statusContentHeight: CGFloat = 20

  private let statusItem: NSStatusItem
  private let statusContentView: ProxyStatusItemView
  private let monitor: TrafficMonitor
  private let statisticsController: TrafficStatisticsController
  private let quotaController: RuntimeQuotaTrackingController
  private let profileQuotaController: ProfileQuotaTrackingController
  private let updateModel: AppUpdateModel
  private let actions: MenuBarPresentationActions
  private let statusMenuPresentationState = StatusMenuPresentationState()
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
    super.init()

    configureStatusItem()
    statusItem.menu = statusMenuController.menu
    observeMonitor()
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
    let primaryContentController = makeHostingController(
      rootView: StatusMenuPrimaryContentView(
        monitor: monitor,
        showControllerSettings: { [weak self] in
          self?.performMenuAction {
            self?.actions.showControllerSettings()
          }
        }
      ),
      contentSize: monitor.hasValidatedControllerConfiguration
        ? StatusMenuLayout.configuredPrimaryContentSize
        : StatusMenuLayout.unconfiguredPrimaryContentSize
    )
    let summaryContentController = makeHostingController(
      rootView: StatusMenuSummaryContentView(
        presentationState: statusMenuPresentationState,
        monitor: monitor,
        statisticsController: statisticsController,
        quotaController: quotaController,
        profileQuotaController: profileQuotaController
      ),
      contentSize: StatusMenuLayout.summaryContentSize
    )

    let controller = StatusMenuController(
      primaryContentViewController: primaryContentController,
      configuredPrimaryContentSize: StatusMenuLayout.configuredPrimaryContentSize,
      unconfiguredPrimaryContentSize: StatusMenuLayout.unconfiguredPrimaryContentSize,
      summaryContentViewController: summaryContentController,
      summaryContentSize: StatusMenuLayout.summaryContentSize,
      submenuConfigurations: makeStatusSubmenuConfigurations(),
      configuredActionItems: makeStatisticsNavigationItems(),
      isConfigurationAvailable: { [weak self] in
        self?.monitor.hasValidatedControllerConfiguration ?? false
      },
      prepareForPresentation: { [weak self] in
        self?.statusMenuPresentationState.prepareForPresentation()
      }
    )
    appendNativeActions(to: controller.menu)
    return controller
  }

  private func makeStatusSubmenuConfigurations() -> [StatusMenuSubmenuConfiguration] {
    let proxyConnectionsController = makeHostingController(
      rootView: ProxyConnectionTopListView(monitor: monitor),
      contentSize: StatusMenuLayout.connectionSubmenuSize
    )
    let directConnectionsController = makeHostingController(
      rootView: DirectConnectionTopListView(monitor: monitor),
      contentSize: StatusMenuLayout.connectionSubmenuSize
    )
    let classificationController = makeHostingController(
      rootView: TrafficClassificationView(monitor: monitor),
      contentSize: StatusMenuLayout.classificationSubmenuSize
    )
    let routingController = makeHostingController(
      rootView: RoutingStatusView(monitor: monitor),
      contentSize: StatusMenuLayout.routingSubmenuSize
    )

    return [
      StatusMenuSubmenuConfiguration(
        title: "活动 Proxy Top 5",
        summary: { [weak self] in
          guard let self else {
            return "暂无传输"
          }
          return ConnectionAnalyticsPresentation.activeConnectionSummary(
            from: self.monitor.liveProxyConnections
          )
        },
        contentViewController: proxyConnectionsController,
        contentSize: StatusMenuLayout.connectionSubmenuSize
      ),
      StatusMenuSubmenuConfiguration(
        title: "活动直连 Top 5",
        summary: { [weak self] in
          guard let self else {
            return "暂无传输"
          }
          return ConnectionAnalyticsPresentation.activeConnectionSummary(
            from: self.monitor.liveDirectConnections
          )
        },
        contentViewController: directConnectionsController,
        contentSize: StatusMenuLayout.connectionSubmenuSize
      ),
      StatusMenuSubmenuConfiguration(
        title: "分类状态",
        summary: { [weak self] in
          TrafficRateFormatter.percentage(from: self?.monitor.coverage)
        },
        contentViewController: classificationController,
        contentSize: StatusMenuLayout.classificationSubmenuSize
      ),
      StatusMenuSubmenuConfiguration(
        title: "路由状态",
        summary: { [weak self] in
          self?.routingStatusPresentation.statusSummary ?? "—"
        },
        contentViewController: routingController,
        contentSize: StatusMenuLayout.routingSubmenuSize
      ),
    ]
  }

  private func makeHostingController<Content: View>(
    rootView: Content,
    contentSize: NSSize
  ) -> NSHostingController<Content> {
    let controller = NSHostingController(rootView: rootView)
    controller.sizingOptions = []
    controller.preferredContentSize = contentSize
    return controller
  }

  private func makeStatisticsNavigationItems() -> [NSMenuItem] {
    let proxyTrafficItem = NSMenuItem(
      title: "查看 Proxy 流量统计",
      action: #selector(showProxyTrafficStatistics),
      keyEquivalent: ""
    )
    proxyTrafficItem.target = self

    let subscriptionQuotaItem = NSMenuItem(
      title: "查看订阅余额统计",
      action: #selector(showSubscriptionQuotaStatistics),
      keyEquivalent: ""
    )
    subscriptionQuotaItem.target = self
    return [proxyTrafficItem, subscriptionQuotaItem]
  }

  private func appendNativeActions(to menu: NSMenu) {
    menu.addItem(.separator())

    let settingsItem = NSMenuItem(
      title: "Mihomo 连接设置…",
      action: #selector(showControllerSettings),
      keyEquivalent: ","
    )
    settingsItem.target = self
    settingsItem.keyEquivalentModifierMask = [.command]
    menu.addItem(settingsItem)

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

  private var routingStatusPresentation: RoutingStatusPresentation {
    RoutingStatusPresentation(
      activeProxyLeaves: monitor.activeProxyLeaves,
      activeRuleTypes: monitor.activeRuleTypes,
      runtimeConfiguration: monitor.runtimeConfiguration
    )
  }
}
