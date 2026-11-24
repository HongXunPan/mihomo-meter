import AppKit

@MainActor
final class ProxyStatusItemView: NSView {
  enum Layout {
    static let statusHeight: CGFloat = 20
    static let statusHorizontalInset: CGFloat = 4
    static let iconSize: CGFloat = 18
    static let rateFontSize: CGFloat = 8
    static let stateFontSize: CGFloat = 8
    static let horizontalSpacing: CGFloat = 2
  }

  private let directRenderer = ProxyStatusItemDirectRenderer()

  init() {
    super.init(frame: .zero)
    setAccessibilityElement(false)
    update(rate: .zero, state: .disconnected)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("不支持通过 NSCoder 初始化")
  }

  func attach(to button: NSView) {
    let inset = Layout.statusHorizontalInset
    frame = NSRect(
      x: inset,
      y: max(0, (button.bounds.height - Layout.statusHeight) / 2),
      width: max(0, button.bounds.width - inset * 2),
      height: Layout.statusHeight
    )
    translatesAutoresizingMaskIntoConstraints = true
    autoresizingMask = [.width, .minYMargin, .maxYMargin]
    button.addSubview(self)
  }

  func update(
    rate: TrafficRate,
    state: MonitorConnectionState
  ) {
    if directRenderer.update(rate: rate, state: state) {
      needsDisplay = true
    }
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    directRenderer.refreshIcons()
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    directRenderer.draw(in: bounds)
  }
}
