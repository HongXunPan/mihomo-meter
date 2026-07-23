import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
  private let statusItem: NSStatusItem
  private let popover: NSPopover

  override init() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    popover = NSPopover()
    super.init()

    configureStatusItem()
    configurePopover()
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
    popover.contentSize = NSSize(width: 320, height: 210)
    popover.contentViewController = NSHostingController(
      rootView: TrafficPopoverView(rate: .zero)
    )
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
