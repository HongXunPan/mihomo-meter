import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
  private let statusItem: NSStatusItem
  private let popover: NSPopover
  private let monitor: TrafficMonitor
  private var cancellables: Set<AnyCancellable> = []

  init(monitor: TrafficMonitor) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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

    button.title = TrafficRateFormatter.statusTitle(for: .zero)
    button.toolTip = "Mihomo Meter"
    button.target = self
    button.action = #selector(togglePopover)
    button.sendAction(on: [.leftMouseUp])
  }

  private func configurePopover() {
    popover.behavior = .transient
    popover.contentSize = NSSize(width: 380, height: 560)
    popover.contentViewController = NSHostingController(
      rootView: TrafficPopoverView(monitor: monitor)
    )
  }

  private func observeMonitor() {
    monitor.$rates
      .combineLatest(monitor.$connectionState)
      .sink { [weak self] rate, state in
        guard let button = self?.statusItem.button else {
          return
        }

        button.title = TrafficRateFormatter.statusTitle(for: rate.proxy)
        button.toolTip = "Mihomo Meter · \(state.title)"
      }
      .store(in: &cancellables)
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
