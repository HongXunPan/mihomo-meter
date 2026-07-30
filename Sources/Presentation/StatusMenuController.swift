import AppKit

@MainActor
struct StatusMenuContentConfiguration {
  let viewController: NSViewController
  let contentSize: () -> NSSize
}

@MainActor
struct StatusMenuSubmenuConfiguration {
  let title: String
  let summary: () -> String
  let contentViewController: NSViewController
  let contentSize: NSSize
}

@MainActor
struct StatusMenuSectionConfiguration {
  let content: StatusMenuContentConfiguration
  let navigationItem: NSMenuItem
}

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
  let menu = NSMenu()

  private let primaryContentEntry: StatusMenuContentEntry
  private let configuredContentEntries: [StatusMenuContentEntry]
  private let configuredItems: [NSMenuItem]
  private let submenuEntries: [StatusMenuSubmenuEntry]
  private let isConfigurationAvailable: () -> Bool
  private let prepareForPresentation: () -> Void
  private let retainedContentViewControllers: [NSViewController]

  init(
    primaryContent: StatusMenuContentConfiguration,
    submenuConfigurations: [StatusMenuSubmenuConfiguration],
    sectionConfigurations: [StatusMenuSectionConfiguration],
    isConfigurationAvailable: @escaping () -> Bool,
    prepareForPresentation: @escaping () -> Void = {}
  ) {
    primaryContentEntry = Self.contentEntry(configuration: primaryContent)
    self.isConfigurationAvailable = isConfigurationAvailable
    self.prepareForPresentation = prepareForPresentation

    var submenuEntries: [StatusMenuSubmenuEntry] = []
    var retainedContentViewControllers = [primaryContent.viewController]
    for configuration in submenuConfigurations {
      let submenu = NSMenu()
      submenu.autoenablesItems = false
      submenu.addItem(
        Self.fixedContentItem(
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
      submenuEntries.append(
        StatusMenuSubmenuEntry(
          item: item,
          summary: configuration.summary
        )
      )
      retainedContentViewControllers.append(configuration.contentViewController)
    }
    self.submenuEntries = submenuEntries

    let sectionEntries = sectionConfigurations.map {
      StatusMenuSectionEntry(
        content: Self.contentEntry(configuration: $0.content),
        navigationItem: $0.navigationItem
      )
    }
    configuredContentEntries = sectionEntries.map(\.content)
    retainedContentViewControllers.append(
      contentsOf: sectionConfigurations.map(\.content.viewController)
    )
    self.retainedContentViewControllers = retainedContentViewControllers

    var configuredItems: [NSMenuItem] = [.separator()]
    configuredItems.append(contentsOf: submenuEntries.map(\.item))
    configuredItems.append(.separator())
    for (index, entry) in sectionEntries.enumerated() {
      configuredItems.append(entry.content.item)
      configuredItems.append(entry.navigationItem)
      if index < sectionEntries.count - 1 {
        configuredItems.append(.separator())
      }
    }
    self.configuredItems = configuredItems

    super.init()

    menu.autoenablesItems = false
    menu.delegate = self
    menu.addItem(primaryContentEntry.item)
    configuredItems.forEach(menu.addItem)
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

  func refreshContentSizes() {
    Self.applyMeasuredSize(to: primaryContentEntry)
    for entry in configuredContentEntries {
      Self.applyMeasuredSize(to: entry)
    }
  }

  func close() {
    menu.cancelTracking()
  }

  private func refreshPresentation() {
    let isAvailable = isConfigurationAvailable()
    for item in configuredItems {
      item.isHidden = !isAvailable
    }
    refreshContentSizes()
    refreshSummaries()
  }

  @objc
  private func menuDidBeginTracking(_ notification: Notification) {
    Task { @MainActor [weak self] in
      await Task.yield()
      self?.primaryContentEntry.viewController.view.window?.makeFirstResponder(nil)
    }
  }

  private static func contentEntry(
    configuration: StatusMenuContentConfiguration
  ) -> StatusMenuContentEntry {
    let item = NSMenuItem()
    item.view = configuration.viewController.view
    let entry = StatusMenuContentEntry(
      item: item,
      viewController: configuration.viewController,
      contentSize: configuration.contentSize
    )
    applyMeasuredSize(to: entry)
    return entry
  }

  private static func fixedContentItem(
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

  private static func applyMeasuredSize(to entry: StatusMenuContentEntry) {
    let measuredSize = entry.contentSize()
    guard measuredSize.width > 0, measuredSize.height > 0 else {
      return
    }
    entry.viewController.view.frame.size = NSSize(
      width: ceil(measuredSize.width),
      height: ceil(measuredSize.height)
    )
    entry.viewController.view.autoresizingMask = [.width]
  }
}

@MainActor
private struct StatusMenuContentEntry {
  let item: NSMenuItem
  let viewController: NSViewController
  let contentSize: () -> NSSize
}

@MainActor
private struct StatusMenuSubmenuEntry {
  let item: NSMenuItem
  let summary: () -> String
}

@MainActor
private struct StatusMenuSectionEntry {
  let content: StatusMenuContentEntry
  let navigationItem: NSMenuItem
}
