import AppKit

@MainActor
struct StatusMenuSubmenuConfiguration {
  let title: String
  let summary: () -> String
  let contentViewController: NSViewController
  let contentSize: NSSize
}

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
  let menu = NSMenu()

  private let primaryContentViewController: NSViewController
  private let primaryContentItem: NSMenuItem
  private let configuredPrimaryContentSize: NSSize
  private let unconfiguredPrimaryContentSize: NSSize
  private let configuredSectionSeparator = NSMenuItem.separator()
  private let summarySectionSeparator = NSMenuItem.separator()
  private let summaryContentItem: NSMenuItem
  private let configuredActionSeparator: NSMenuItem?
  private let configuredActionItems: [NSMenuItem]
  private let submenuEntries: [StatusMenuSubmenuEntry]
  private let isConfigurationAvailable: () -> Bool
  private let prepareForPresentation: () -> Void
  private let retainedContentViewControllers: [NSViewController]

  init(
    primaryContentViewController: NSViewController,
    configuredPrimaryContentSize: NSSize,
    unconfiguredPrimaryContentSize: NSSize,
    summaryContentViewController: NSViewController,
    summaryContentSize: NSSize,
    submenuConfigurations: [StatusMenuSubmenuConfiguration],
    configuredActionItems: [NSMenuItem] = [],
    isConfigurationAvailable: @escaping () -> Bool,
    prepareForPresentation: @escaping () -> Void
  ) {
    self.primaryContentViewController = primaryContentViewController
    self.configuredPrimaryContentSize = configuredPrimaryContentSize
    self.unconfiguredPrimaryContentSize = unconfiguredPrimaryContentSize
    self.configuredActionItems = configuredActionItems
    configuredActionSeparator =
      configuredActionItems.isEmpty ? nil : NSMenuItem.separator()
    self.isConfigurationAvailable = isConfigurationAvailable
    self.prepareForPresentation = prepareForPresentation

    primaryContentItem = Self.contentItem(
      viewController: primaryContentViewController,
      size: configuredPrimaryContentSize
    )
    summaryContentItem = Self.contentItem(
      viewController: summaryContentViewController,
      size: summaryContentSize
    )

    var entries: [StatusMenuSubmenuEntry] = []
    var contentViewControllers = [
      primaryContentViewController,
      summaryContentViewController,
    ]
    for configuration in submenuConfigurations {
      let submenu = NSMenu()
      submenu.autoenablesItems = false
      submenu.addItem(
        Self.contentItem(
          viewController: configuration.contentViewController,
          size: configuration.contentSize
        )
      )

      let item = NSMenuItem(
        title: configuration.title,
        action: nil,
        keyEquivalent: ""
      )
      item.submenu = submenu
      entries.append(
        StatusMenuSubmenuEntry(
          item: item,
          summary: configuration.summary
        )
      )
      contentViewControllers.append(configuration.contentViewController)
    }
    submenuEntries = entries
    retainedContentViewControllers = contentViewControllers

    super.init()

    menu.autoenablesItems = false
    menu.delegate = self
    menu.addItem(primaryContentItem)
    menu.addItem(configuredSectionSeparator)
    for entry in submenuEntries {
      menu.addItem(entry.item)
    }
    menu.addItem(summarySectionSeparator)
    menu.addItem(summaryContentItem)
    if let configuredActionSeparator {
      menu.addItem(configuredActionSeparator)
    }
    for item in configuredActionItems {
      menu.addItem(item)
    }
    refreshPresentation()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(menuDidBeginTracking(_:)),
      name: NSMenu.didBeginTrackingNotification,
      object: menu
    )
  }

  func menuWillOpen(_ menu: NSMenu) {
    prepareForPresentation()
    refreshPresentation()
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    refreshPresentation()
  }

  func refreshSummaries() {
    guard isConfigurationAvailable() else {
      return
    }

    for entry in submenuEntries {
      let summary = entry.summary()
      entry.item.badge = summary.isEmpty ? nil : NSMenuItemBadge(string: summary)
      entry.item.setAccessibilityLabel(
        summary.isEmpty ? entry.item.title : "\(entry.item.title)，\(summary)"
      )
    }
  }

  func close() {
    menu.cancelTracking()
  }

  private func refreshPresentation() {
    let isAvailable = isConfigurationAvailable()
    let primarySize =
      isAvailable
      ? configuredPrimaryContentSize
      : unconfiguredPrimaryContentSize
    primaryContentItem.view?.frame.size = primarySize
    configuredSectionSeparator.isHidden = !isAvailable
    summarySectionSeparator.isHidden = !isAvailable
    summaryContentItem.isHidden = !isAvailable
    configuredActionSeparator?.isHidden = !isAvailable
    for item in configuredActionItems {
      item.isHidden = !isAvailable
    }
    for entry in submenuEntries {
      entry.item.isHidden = !isAvailable
    }
    refreshSummaries()
  }

  @objc
  private func menuDidBeginTracking(_ notification: Notification) {
    Task { @MainActor [weak self] in
      await Task.yield()
      self?.primaryContentViewController.view.window?.makeFirstResponder(nil)
    }
  }

  private static func contentItem(
    viewController: NSViewController,
    size: NSSize
  ) -> NSMenuItem {
    let contentView = viewController.view
    contentView.frame = NSRect(origin: .zero, size: size)
    contentView.autoresizingMask = [.width, .height]

    let item = NSMenuItem()
    item.view = contentView
    return item
  }
}

@MainActor
private struct StatusMenuSubmenuEntry {
  let item: NSMenuItem
  let summary: () -> String
}
