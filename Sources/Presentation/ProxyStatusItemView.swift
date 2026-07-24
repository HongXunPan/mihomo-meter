import AppKit

@MainActor
final class ProxyStatusItemView: NSView {
  private enum Layout {
    static let proxyFontSize: CGFloat = 10
    static let rateFontSize: CGFloat = 8
    static let stateFontSize: CGFloat = 8
    static let horizontalSpacing: CGFloat = 2
  }

  private let proxyLabel = NSTextField(labelWithString: "P")
  private let downloadLabel = NSTextField(labelWithString: "")
  private let uploadLabel = NSTextField(labelWithString: "")
  private let stateLabel = NSTextField(labelWithString: "")
  private lazy var rateStack = NSStackView(views: [downloadLabel, uploadLabel])

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configureView()
    update(rate: .zero, state: .disconnected)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("不支持通过 NSCoder 初始化")
  }

  func update(
    rate: TrafficRate,
    state: MonitorConnectionState
  ) {
    if state == .connected {
      let statusText = TrafficRateFormatter.statusText(for: rate)
      downloadLabel.stringValue = statusText.download
      uploadLabel.stringValue = statusText.upload
      rateStack.isHidden = false
      stateLabel.isHidden = true
      return
    }

    stateLabel.stringValue = state.statusItemTitle
    rateStack.isHidden = true
    stateLabel.isHidden = false
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  private func configureView() {
    setAccessibilityElement(false)
    configureProxyLabel()
    configureRateLabel(downloadLabel)
    configureRateLabel(uploadLabel)
    configureStateLabel()

    rateStack.orientation = .vertical
    rateStack.alignment = .trailing
    rateStack.distribution = .fillEqually
    rateStack.spacing = 0

    let contentStack = NSStackView(views: [proxyLabel, rateStack, stateLabel])
    contentStack.orientation = .horizontal
    contentStack.alignment = .centerY
    contentStack.distribution = .fill
    contentStack.spacing = Layout.horizontalSpacing
    contentStack.translatesAutoresizingMaskIntoConstraints = false

    addSubview(contentStack)
    NSLayoutConstraint.activate([
      contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
      contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
      contentStack.topAnchor.constraint(equalTo: topAnchor),
      contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  private func configureProxyLabel() {
    proxyLabel.font = NSFont.systemFont(
      ofSize: Layout.proxyFontSize,
      weight: .semibold
    )
    proxyLabel.alignment = .center
    proxyLabel.setAccessibilityElement(false)
    proxyLabel.setContentHuggingPriority(.required, for: .horizontal)
  }

  private func configureRateLabel(_ label: NSTextField) {
    label.font = NSFont.monospacedDigitSystemFont(
      ofSize: Layout.rateFontSize,
      weight: .medium
    )
    label.alignment = .right
    label.cell?.usesSingleLineMode = true
    label.cell?.lineBreakMode = .byClipping
    label.setAccessibilityElement(false)
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
  }

  private func configureStateLabel() {
    stateLabel.font = NSFont.systemFont(
      ofSize: Layout.stateFontSize,
      weight: .medium
    )
    stateLabel.alignment = .right
    stateLabel.cell?.usesSingleLineMode = true
    stateLabel.cell?.lineBreakMode = .byClipping
    stateLabel.setAccessibilityElement(false)
    stateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
  }
}
