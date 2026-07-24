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
  private var cancellables: Set<AnyCancellable> = []

  init(monitor: TrafficMonitor) {
    statusItem = NSStatusBar.system.statusItem(
      withLength: MenuBarController.statusItemLength
    )
    statusContentView = ProxyStatusItemView()
    popover = NSPopover()
    self.monitor = monitor
    super.init()

    configureStatusItem()
    configurePopover()
    observeMonitor()
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
    let hostingController = NSHostingController(
      rootView: TrafficPopoverView(monitor: monitor)
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
      popover.performClose(nil)
      return
    }

    guard let button = statusItem.button else {
      return
    }

    popover.show(
      relativeTo: button.bounds,
      of: button,
      preferredEdge: .minY
    )
  }
}
