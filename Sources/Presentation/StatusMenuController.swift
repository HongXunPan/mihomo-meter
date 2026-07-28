import AppKit

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
  let menu = NSMenu()

  private let contentViewController: NSViewController
  private let prepareForPresentation: () -> Void

  init(
    contentViewController: NSViewController,
    contentSize: NSSize,
    prepareForPresentation: @escaping () -> Void
  ) {
    self.contentViewController = contentViewController
    self.prepareForPresentation = prepareForPresentation
    super.init()

    let contentView = contentViewController.view
    contentView.frame = NSRect(origin: .zero, size: contentSize)
    contentView.autoresizingMask = [.width, .height]

    let contentItem = NSMenuItem()
    contentItem.view = contentView

    menu.autoenablesItems = false
    menu.delegate = self
    menu.addItem(contentItem)
  }

  func menuWillOpen(_ menu: NSMenu) {
    prepareForPresentation()
  }

  func close() {
    menu.cancelTracking()
  }
}
