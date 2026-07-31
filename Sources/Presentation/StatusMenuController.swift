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
  let prepareForPresentation: () -> Void

  init(
    title: String,
    summary: @escaping () -> String,
    contentViewController: NSViewController,
    contentSize: NSSize,
    prepareForPresentation: @escaping () -> Void = {}
  ) {
    self.title = title
    self.summary = summary
    self.contentViewController = contentViewController
    self.contentSize = contentSize
    self.prepareForPresentation = prepareForPresentation
  }
}

@MainActor
struct StatusMenuSectionConfiguration {
  let content: StatusMenuContentConfiguration
  let submenuConfigurations: [StatusMenuSubmenuConfiguration]
  let navigationItem: NSMenuItem

  init(
    content: StatusMenuContentConfiguration,
    submenuConfigurations: [StatusMenuSubmenuConfiguration] = [],
    navigationItem: NSMenuItem
  ) {
    self.content = content
    self.submenuConfigurations = submenuConfigurations
    self.navigationItem = navigationItem
  }
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

    let leadingSubmenuEntries = submenuConfigurations.map(Self.submenuEntry)

    let sectionEntries = sectionConfigurations.map {
      StatusMenuSectionEntry(
        content: Self.contentEntry(configuration: $0.content),
        submenuEntries: $0.submenuConfigurations.map(Self.submenuEntry),
        navigationItem: $0.navigationItem
      )
    }
    submenuEntries =
      leadingSubmenuEntries
      + sectionEntries.flatMap(\.submenuEntries)
    configuredContentEntries = sectionEntries.map(\.content)
    var retainedContentViewControllers = [primaryContent.viewController]
    retainedContentViewControllers.append(
      contentsOf: submenuConfigurations.map(\.contentViewController)
    )
    retainedContentViewControllers.append(contentsOf: sectionEntries.map(\.content.viewController))
    retainedContentViewControllers.append(
      contentsOf: sectionConfigurations.flatMap {
        $0.submenuConfigurations.map(\.contentViewController)
      }
    )
    self.retainedContentViewControllers = retainedContentViewControllers

    var configuredItems: [NSMenuItem] = [.separator()]
    configuredItems.append(contentsOf: leadingSubmenuEntries.map(\.item))
    configuredItems.append(.separator())
    for (index, entry) in sectionEntries.enumerated() {
      configuredItems.append(entry.content.item)
      configuredItems.append(contentsOf: entry.submenuEntries.map(\.item))
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
    refreshPresentation(prepareSubmenus: false)
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

  private func refreshPresentation(prepareSubmenus: Bool = true) {
    let isAvailable = isConfigurationAvailable()
    for item in configuredItems {
      item.isHidden = !isAvailable
    }
    if prepareSubmenus {
      for entry in submenuEntries {
        entry.prepareForPresentation()
      }
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

  private static func submenuEntry(
    configuration: StatusMenuSubmenuConfiguration
  ) -> StatusMenuSubmenuEntry {
    let submenu = NSMenu()
    submenu.autoenablesItems = false
    submenu.addItem(
      fixedContentItem(
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
    return StatusMenuSubmenuEntry(
      item: item,
      summary: configuration.summary,
      prepareForPresentation: configuration.prepareForPresentation
    )
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
  let prepareForPresentation: () -> Void
}

@MainActor
private struct StatusMenuSectionEntry {
  let content: StatusMenuContentEntry
  let submenuEntries: [StatusMenuSubmenuEntry]
  let navigationItem: NSMenuItem
}
