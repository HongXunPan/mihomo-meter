import Foundation

enum AppActivationTarget: String, Equatable, Sendable {
  case mainWindow
  case statistics
  case subscriptionQuota
  case controllerSettings
}

enum AppDeepLink {
  static let fallbackTarget = AppActivationTarget.mainWindow
  static let statisticsURL = "mihomo-meter://statistics"
  static let subscriptionQuotaURL = "mihomo-meter://subscription-quota"
  static let connectionSettingsURL = "mihomo-meter://connection-settings"

  static func target(for url: URL) -> AppActivationTarget? {
    switch url.absoluteString {
    case statisticsURL:
      .statistics
    case subscriptionQuotaURL:
      .subscriptionQuota
    case connectionSettingsURL:
      .controllerSettings
    default:
      nil
    }
  }
}
