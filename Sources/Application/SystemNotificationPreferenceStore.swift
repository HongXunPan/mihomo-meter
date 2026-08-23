import Foundation

struct SystemNotificationPreferences: Equatable, Sendable {
  var isEnabled: Bool
  var disconnectAlertsEnabled: Bool
  var deliveredKeys: Set<String>
}

@MainActor
protocol SystemNotificationPreferenceStoring: AnyObject {
  func load() -> SystemNotificationPreferences
  func saveEnabled(_ enabled: Bool)
  func saveDisconnectAlertsEnabled(_ enabled: Bool)
  func saveDeliveredKeys(_ keys: Set<String>)
}

@MainActor
final class UserDefaultsSystemNotificationPreferenceStore:
  SystemNotificationPreferenceStoring
{
  private enum Key {
    static let enabled = "systemNotifications.enabled"
    static let disconnectAlertsEnabled = "systemNotifications.disconnectAlertsEnabled"
    static let deliveredKeys = "systemNotifications.deliveredKeys"
  }

  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  func load() -> SystemNotificationPreferences {
    SystemNotificationPreferences(
      isEnabled: userDefaults.bool(forKey: Key.enabled),
      disconnectAlertsEnabled: userDefaults.bool(forKey: Key.disconnectAlertsEnabled),
      deliveredKeys: Set(userDefaults.stringArray(forKey: Key.deliveredKeys) ?? [])
    )
  }

  func saveEnabled(_ enabled: Bool) {
    userDefaults.set(enabled, forKey: Key.enabled)
  }

  func saveDisconnectAlertsEnabled(_ enabled: Bool) {
    userDefaults.set(enabled, forKey: Key.disconnectAlertsEnabled)
  }

  func saveDeliveredKeys(_ keys: Set<String>) {
    userDefaults.set(keys.sorted(), forKey: Key.deliveredKeys)
  }
}
