import AppKit
import SwiftUI

enum MihomoColorToken {
  static let brandPrimary = adaptive(
    light: color(red: 0x00, green: 0x6D, blue: 0x68),
    dark: color(red: 0x62, green: 0xD4, blue: 0xCB)
  )
  static let interactiveAccent = adaptive(
    light: color(red: 0x00, green: 0x6D, blue: 0x68),
    dark: color(red: 0x00, green: 0x82, blue: 0x7B)
  )

  static let statusInfo = brandPrimary
  static let statusSuccess = adaptive(
    light: color(red: 0x16, green: 0x78, blue: 0x4A),
    dark: color(red: 0x5F, green: 0xD1, blue: 0x9A)
  )
  static let statusWarning = adaptive(
    light: color(red: 0x99, green: 0x50, blue: 0x00),
    dark: color(red: 0xFF, green: 0xB8, blue: 0x6B)
  )
  static let statusDanger = adaptive(
    light: color(red: 0xB3, green: 0x26, blue: 0x35),
    dark: color(red: 0xFF, green: 0x8E, blue: 0x9A)
  )
  static let statusDangerBackground = adaptive(
    light: color(red: 0xB3, green: 0x26, blue: 0x35, alpha: 0.08),
    dark: color(red: 0xFF, green: 0x8E, blue: 0x9A, alpha: 0.14)
  )
  static let statusNeutral: Color = .secondary

  static let trafficDownload = adaptive(
    light: color(red: 0x0B, green: 0x5C, blue: 0xAD),
    dark: color(red: 0x72, green: 0xA7, blue: 0xFF)
  )
  static let trafficUpload = adaptive(
    light: color(red: 0xA3, green: 0x3B, blue: 0x00),
    dark: color(red: 0xFF, green: 0x9C, blue: 0x6B)
  )
  static let trafficTotal = adaptive(
    light: color(red: 0x8B, green: 0x3A, blue: 0x72),
    dark: color(red: 0xF0, green: 0x8F, blue: 0xCB)
  )
  static let trafficDownloadArea = adaptive(
    light: color(red: 0x0B, green: 0x5C, blue: 0xAD, alpha: 0.75),
    dark: color(red: 0x72, green: 0xA7, blue: 0xFF, alpha: 0.55)
  )
  static let trafficUploadArea = adaptive(
    light: color(red: 0xA3, green: 0x3B, blue: 0x00, alpha: 0.75),
    dark: color(red: 0xFF, green: 0x9C, blue: 0x6B, alpha: 0.55)
  )

  private static func adaptive(light: NSColor, dark: NSColor) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
      }
    )
  }

  private static func color(
    red: Int,
    green: Int,
    blue: Int,
    alpha: CGFloat = 1
  ) -> NSColor {
    NSColor(
      srgbRed: CGFloat(red) / 255,
      green: CGFloat(green) / 255,
      blue: CGFloat(blue) / 255,
      alpha: alpha
    )
  }
}

extension View {
  func mihomoTheme() -> some View {
    tint(MihomoColorToken.interactiveAccent)
  }
}
