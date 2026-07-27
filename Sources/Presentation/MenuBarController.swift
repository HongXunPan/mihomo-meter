import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
  private static let statusItemLength: CGFloat = 58
  private static let statusContentHeight: CGFloat = 20

  private let statusItem: NSStatusItem
  private let statusContentView: ProxyStatusItemView
  private let popover: NSPopover
  private let monitor: TrafficMonitor
  private let statisticsController: TrafficStatisticsController
  private let quotaController: RuntimeQuotaTrackingController
  private let profileQuotaController: ProfileQuotaTrackingController
  private let statisticsWindowController: TrafficStatisticsWindowController
  private let updateModel: AppUpdateModel
  private var cancellables: Set<AnyCancellable> = []
  private var globalMouseMonitor: Any?
  private var isPopoverPresentationPending = false
  private var pendingStatisticsModule: StatisticsModule?

  init(
    monitor: TrafficMonitor,
    statisticsController: TrafficStatisticsController,
    quotaController: RuntimeQuotaTrackingController,
    profileQuotaController: ProfileQuotaTrackingController,
    profileController: ClashProfileDirectoryController,
    updateModel: AppUpdateModel
  ) {
    statusItem = NSStatusBar.system.statusItem(
      withLength: MenuBarController.statusItemLength
    )
    statusContentView = ProxyStatusItemView()
    popover = NSPopover()
    self.monitor = monitor
    self.statisticsController = statisticsController
    self.quotaController = quotaController
    self.profileQuotaController = profileQuotaController
    statisticsWindowController = TrafficStatisticsWindowController(
      controller: statisticsController,
      quotaController: quotaController,
      profileQuotaController: profileQuotaController,
      profileController: profileController,
      monitor: monitor
    )
    self.updateModel = updateModel
    super.init()

    configureStatusItem()
    configurePopover()
    observeMonitor()
    observeApplication()
  }

  private func configureStatusItem() {
    guard let button = statusItem.button else {
      return
    }

    button.title = ""
    button.setAccessibilityLabel("Mihomo Meter")
    button.target = self
    button.action = #selector(togglePopover)
    button.sendAction(on: [.leftMouseUp])

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

  private func configurePopover() {
    popover.behavior = .transient
    popover.delegate = self
    let hostingController = NSHostingController(
      rootView: TrafficPopoverView(
        monitor: monitor,
        statisticsController: statisticsController,
        quotaController: quotaController,
        profileQuotaController: profileQuotaController,
        updateModel: updateModel,
        showAllStatistics: { [weak self] in
          self?.showStatisticsWindow(module: .proxyTraffic)
        },
        showQuotaStatistics: { [weak self] in
          self?.showStatisticsWindow(module: .subscriptionQuota)
        },
        dismiss: { [weak self] in
          self?.closePopover()
        }
      )
    )
    hostingController.sizingOptions = []
    hostingController.preferredContentSize = TrafficPopoverLayout.contentSize

    popover.contentViewController = hostingController
    popover.contentSize = TrafficPopoverLayout.contentSize
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

  private func observeApplication() {
    NotificationCenter.default.publisher(
      for: NSApplication.didBecomeActiveNotification,
      object: NSApplication.shared
    )
    .sink { [weak self] _ in
      self?.presentPendingPopover()
    }
    .store(in: &cancellables)

    NotificationCenter.default.publisher(
      for: NSApplication.didResignActiveNotification,
      object: NSApplication.shared
    )
    .sink { [weak self] _ in
      self?.isPopoverPresentationPending = false
      self?.closePopover()
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

  @objc
  private func togglePopover() {
    if popover.isShown {
      closePopover()
      return
    }

    guard !NSApplication.shared.isActive else {
      showPopover()
      return
    }

    isPopoverPresentationPending = true
    activateApplication()
  }

  private func presentPendingPopover() {
    guard isPopoverPresentationPending, NSApplication.shared.isActive else {
      return
    }
    isPopoverPresentationPending = false
    showPopover()
  }

  private func showPopover() {
    guard let button = statusItem.button else {
      return
    }

    popover.show(
      relativeTo: button.bounds,
      of: button,
      preferredEdge: .minY
    )
    startGlobalMouseMonitoring()

    // 在首帧绘制前清除自动焦点，后续仍可使用 Tab 键导航。
    _ = popover.contentViewController?.view.window?.makeFirstResponder(nil)
  }

  private func activateApplication() {
    // 状态栏点击代表明确用户意图；普通 activate() 在关闭最后一个窗口后可能被系统拒绝。
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  private func startGlobalMouseMonitoring() {
    guard globalMouseMonitor == nil else {
      return
    }

    globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.closePopover()
      }
    }
  }

  private func stopGlobalMouseMonitoring() {
    guard let globalMouseMonitor else {
      return
    }

    NSEvent.removeMonitor(globalMouseMonitor)
    self.globalMouseMonitor = nil
  }

  private func closePopover() {
    guard popover.isShown else {
      return
    }
    popover.performClose(nil)
  }

  private func showStatisticsWindow(module: StatisticsModule) {
    pendingStatisticsModule = module
    guard popover.isShown else {
      presentPendingStatisticsWindow()
      return
    }
    closePopover()
  }

  private func presentPendingStatisticsWindow() {
    guard let module = pendingStatisticsModule else {
      return
    }
    pendingStatisticsModule = nil
    statisticsWindowController.show(module: module)
  }
}

extension MenuBarController: NSPopoverDelegate {
  func popoverDidClose(_ notification: Notification) {
    stopGlobalMouseMonitoring()
    presentPendingStatisticsWindow()
  }
}
