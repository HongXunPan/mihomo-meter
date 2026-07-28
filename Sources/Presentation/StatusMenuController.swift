import AppKit

@MainActor
final class StatusMenuController {
  let menu = NSMenu()

  private let contentViewController: NSViewController

  init(contentViewController: NSViewController, contentSize: NSSize) {
    self.contentViewController = contentViewController

    let contentView = contentViewController.view
    contentView.frame = NSRect(origin: .zero, size: contentSize)
    contentView.autoresizingMask = [.width, .height]

    let contentItem = NSMenuItem()
    contentItem.view = contentView

    menu.autoenablesItems = false
    menu.addItem(contentItem)
  }

  func close() {
    menu.cancelTracking()
  }
}
