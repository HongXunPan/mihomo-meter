import AppKit
import SwiftUI

enum MihomoColorToken {
  static let brandPrimary = adaptive(
    light: color(red: 0x00, green: 0x7A, blue: 0x73),
    dark: color(red: 0x56, green: 0xCF, blue: 0xC5)
  )

  static let statusSuccess = adaptive(
    light: color(red: 0x15, green: 0x80, blue: 0x3D),
    dark: color(red: 0x4A, green: 0xDE, blue: 0x80)
  )
  static let statusWarning = adaptive(
    light: color(red: 0xB4, green: 0x53, blue: 0x09),
    dark: color(red: 0xF5, green: 0x9E, blue: 0x0B)
  )
  static let statusWarningBackground = adaptive(
    light: color(red: 0xB4, green: 0x53, blue: 0x09, alpha: 0.08),
    dark: color(red: 0xF5, green: 0x9E, blue: 0x0B, alpha: 0.14)
  )
  static let statusDanger = adaptive(
    light: color(red: 0xB9, green: 0x1C, blue: 0x1C),
    dark: color(red: 0xFB, green: 0x71, blue: 0x85)
  )
  static let statusDangerBackground = adaptive(
    light: color(red: 0xB9, green: 0x1C, blue: 0x1C, alpha: 0.08),
    dark: color(red: 0xFB, green: 0x71, blue: 0x85, alpha: 0.14)
  )
  static let statusNeutral: Color = .secondary

  static let trafficProxy = adaptive(
    light: color(red: 0x66, green: 0x52, blue: 0x8F),
    dark: color(red: 0xB5, green: 0xA4, blue: 0xD6)
  )
  static let trafficDirect = adaptive(
    light: color(red: 0x62, green: 0x6A, blue: 0x77),
    dark: color(red: 0x9C, green: 0xA3, blue: 0xAF)
  )
  static let trafficUnknown = adaptive(
    light: color(red: 0xA1, green: 0x62, blue: 0x07),
    dark: color(red: 0xEA, green: 0xB3, blue: 0x08)
  )
  static let trafficDownload = adaptive(
    light: color(red: 0x0B, green: 0x5C, blue: 0xAD),
    dark: color(red: 0x72, green: 0xA7, blue: 0xFF)
  )
  static let trafficUpload = adaptive(
    light: color(red: 0xC2, green: 0x41, blue: 0x0C),
    dark: color(red: 0xFB, green: 0x92, blue: 0x3C)
  )
  static let trafficDownloadArea = adaptive(
    light: color(red: 0x0B, green: 0x5C, blue: 0xAD, alpha: 0.28),
    dark: color(red: 0x72, green: 0xA7, blue: 0xFF, alpha: 0.24)
  )
  static let trafficUploadArea = adaptive(
    light: color(red: 0xC2, green: 0x41, blue: 0x0C, alpha: 0.28),
    dark: color(red: 0xFB, green: 0x92, blue: 0x3C, alpha: 0.24)
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
