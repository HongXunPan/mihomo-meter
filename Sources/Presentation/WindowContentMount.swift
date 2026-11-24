import AppKit

@MainActor
final class WindowContentMount {
  private let makeContentViewController: () -> NSViewController

  init(makeContentViewController: @escaping () -> NSViewController) {
    self.makeContentViewController = makeContentViewController
  }

  func attach(to window: NSWindow) {
    guard window.contentViewController == nil else {
      return
    }
    let frame = window.frame
    window.contentViewController = makeContentViewController()
    // 重新挂载内容时保持用户调整过的窗口位置和尺寸。
    window.setFrame(frame, display: false)
  }

  func detach(from window: NSWindow) {
    guard window.contentViewController != nil else {
      return
    }
    // 替换内容视图会解除窗口对旧 SwiftUI 托管树的持有。
    window.contentView = NSView(frame: window.contentView?.bounds ?? .zero)
  }
}
