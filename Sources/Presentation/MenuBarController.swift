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
    let hostingController = NSHostingController(
      rootView: StatusMenuContentView(
        presentationState: statusMenuPresentationState,
        monitor: monitor,
        statisticsController: statisticsController,
        quotaController: quotaController,
        profileQuotaController: profileQuotaController,
        showAllStatistics: { [weak self] in
          self?.performMenuAction {
            self?.actions.showStatistics(.proxyTraffic)
          }
        },
        showQuotaStatistics: { [weak self] in
          self?.performMenuAction {
            self?.actions.showStatistics(.subscriptionQuota)
          }
        }
      )
      .mihomoTheme()
    )
    hostingController.sizingOptions = []
    hostingController.preferredContentSize = StatusMenuLayout.contentSize

    let controller = StatusMenuController(
      contentViewController: hostingController,
      contentSize: StatusMenuLayout.contentSize,
      prepareForPresentation: { [weak self] in
        self?.statusMenuPresentationState.prepareForPresentation()
      }
    )
    appendNativeActions(to: controller.menu)
    return controller
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
