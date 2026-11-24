import AppKit

@MainActor
final class ProxyStatusItemDirectRenderer {
  private enum Content: Equatable {
    case rate(download: String, upload: String)
    case state(String)
  }

  private var content: Content = .state("")
  private var icon: NSImage?
  private var accentIcon: NSImage?

  init() {
    refreshIcons()
  }

  func update(rate: TrafficRate, state: MonitorConnectionState) -> Bool {
    let next: Content
    if state == .connected {
      let statusText = TrafficRateFormatter.statusText(for: rate)
      next = .rate(download: statusText.download, upload: statusText.upload)
    } else {
      next = .state(state.statusItemTitle)
    }
    guard next != content else {
      return false
    }
    content = next
    return true
  }

  func refreshIcons() {
    icon = Self.tintedIcon(named: "StatusBarTemplate", color: .labelColor)
    accentIcon = Self.tintedIcon(
      named: "StatusBarAccentTemplate",
      color: MihomoColorToken.brandPrimaryNSColor
    )
  }

  func draw(in bounds: NSRect) {
    let layout = ProxyStatusItemView.Layout.self
    let iconRect = NSRect(x: 0, y: 1, width: layout.iconSize, height: layout.iconSize)
    icon?.draw(in: iconRect)
    accentIcon?.draw(in: iconRect)

    let textX = layout.iconSize + layout.horizontalSpacing
    let textWidth = max(0, bounds.width - textX)
    let rowHeight = layout.statusHeight / 2
    switch content {
    case .rate(let download, let upload):
      let font = NSFont.monospacedDigitSystemFont(ofSize: layout.rateFontSize, weight: .medium)
      drawText(
        download,
        in: NSRect(x: textX, y: rowHeight, width: textWidth, height: rowHeight),
        font: font
      )
      drawText(
        upload,
        in: NSRect(x: textX, y: 0, width: textWidth, height: rowHeight),
        font: font
      )
    case .state(let title):
      drawText(
        title,
        in: NSRect(x: textX, y: rowHeight / 2, width: textWidth, height: rowHeight),
        font: .systemFont(ofSize: layout.stateFontSize, weight: .medium)
      )
    }
  }

  private func drawText(_ text: String, in rect: NSRect, font: NSFont) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .right
    paragraph.lineBreakMode = .byClipping
    NSAttributedString(
      string: text,
      attributes: [
        .font: font,
        .foregroundColor: NSColor.labelColor,
        .paragraphStyle: paragraph,
      ]
    ).draw(in: rect)
  }

  private static func tintedIcon(named name: String, color: NSColor) -> NSImage? {
    guard let source = NSImage(named: name) else {
      return nil
    }
    let size = ProxyStatusItemView.Layout.iconSize
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
      source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
      color.setFill()
      rect.fill(using: .sourceAtop)
      return true
    }
    image.isTemplate = false
    return image
  }
}
