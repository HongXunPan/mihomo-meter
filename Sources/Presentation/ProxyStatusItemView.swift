import AppKit

@MainActor
final class ProxyStatusItemView: NSView {
  private enum Layout {
    static let iconSize: CGFloat = 18
    static let rateFontSize: CGFloat = 8
    static let stateFontSize: CGFloat = 8
    static let horizontalSpacing: CGFloat = 2
  }

  private let proxyIconContainer = NSView()
  private let proxyIconView = NSImageView()
  private let proxyIconAccentView = NSImageView()
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
    configureProxyIconView()
    configureRateLabel(downloadLabel)
    configureRateLabel(uploadLabel)
    configureStateLabel()

    rateStack.orientation = .vertical
    rateStack.alignment = .trailing
    rateStack.distribution = .fillEqually
    rateStack.spacing = 0

    let contentStack = NSStackView(views: [proxyIconContainer, rateStack, stateLabel])
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

  private func configureProxyIconView() {
    configureIconLayer(
      proxyIconView,
      imageName: "StatusBarTemplate",
      tintColor: .labelColor
    )
    configureIconLayer(
      proxyIconAccentView,
      imageName: "StatusBarAccentTemplate",
      tintColor: MihomoColorToken.brandPrimaryNSColor
    )

    proxyIconContainer.setAccessibilityElement(false)
    proxyIconContainer.setContentHuggingPriority(.required, for: .horizontal)
    proxyIconContainer.addSubview(proxyIconView)
    proxyIconContainer.addSubview(proxyIconAccentView)
    NSLayoutConstraint.activate([
      proxyIconContainer.widthAnchor.constraint(equalToConstant: Layout.iconSize),
      proxyIconContainer.heightAnchor.constraint(equalToConstant: Layout.iconSize),
      proxyIconView.leadingAnchor.constraint(equalTo: proxyIconContainer.leadingAnchor),
      proxyIconView.trailingAnchor.constraint(equalTo: proxyIconContainer.trailingAnchor),
      proxyIconView.topAnchor.constraint(equalTo: proxyIconContainer.topAnchor),
      proxyIconView.bottomAnchor.constraint(equalTo: proxyIconContainer.bottomAnchor),
      proxyIconAccentView.leadingAnchor.constraint(equalTo: proxyIconContainer.leadingAnchor),
      proxyIconAccentView.trailingAnchor.constraint(equalTo: proxyIconContainer.trailingAnchor),
      proxyIconAccentView.topAnchor.constraint(equalTo: proxyIconContainer.topAnchor),
      proxyIconAccentView.bottomAnchor.constraint(equalTo: proxyIconContainer.bottomAnchor),
    ])
  }

  private func configureIconLayer(
    _ imageView: NSImageView,
    imageName: String,
    tintColor: NSColor
  ) {
    let image = NSImage(named: imageName)
    image?.isTemplate = true
    imageView.image = image
    imageView.imageAlignment = .alignCenter
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.contentTintColor = tintColor
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.setAccessibilityElement(false)
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
