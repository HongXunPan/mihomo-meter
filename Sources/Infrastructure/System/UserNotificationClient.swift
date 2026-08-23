@preconcurrency import UserNotifications

@MainActor
protocol SystemNotificationDelivering: AnyObject {
  var activationHandler: ((AppActivationTarget) -> Void)? { get set }

  func authorizationStatus() async -> SystemNotificationAuthorization
  func requestAuthorization() async throws -> SystemNotificationAuthorization
  func deliver(_ delivery: SystemNotificationDelivery) async throws
}

@MainActor
final class UserNotificationClient: NSObject, SystemNotificationDelivering {
  var activationHandler: ((AppActivationTarget) -> Void)?

  private let center: UNUserNotificationCenter

  init(center: UNUserNotificationCenter = .current()) {
    self.center = center
    super.init()
    center.delegate = self
  }

  func authorizationStatus() async -> SystemNotificationAuthorization {
    await withCheckedContinuation { continuation in
      center.getNotificationSettings { settings in
        continuation.resume(
          returning: mapSystemNotificationAuthorization(settings.authorizationStatus)
        )
      }
    }
  }

  func requestAuthorization() async throws -> SystemNotificationAuthorization {
    let granted = try await center.requestAuthorization(options: [.alert, .sound])
    if granted {
      return .authorized
    }
    return await authorizationStatus()
  }

  func deliver(_ delivery: SystemNotificationDelivery) async throws {
    let content = UNMutableNotificationContent()
    content.title = delivery.title
    content.body = delivery.body
    content.sound = .default
    content.userInfo = ["target": delivery.target.rawValue]
    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )
    try await center.add(request)
  }

}

private func mapSystemNotificationAuthorization(
  _ status: UNAuthorizationStatus
) -> SystemNotificationAuthorization {
  switch status {
  case .notDetermined:
    .notDetermined
  case .authorized, .provisional, .ephemeral:
    .authorized
  case .denied:
    .denied
  @unknown default:
    .unknown
  }
}

extension UserNotificationClient: UNUserNotificationCenterDelegate {
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let rawTarget = response.notification.request.content.userInfo["target"] as? String
    completionHandler()
    Task { @MainActor [weak self] in
      if let rawTarget, let target = AppActivationTarget(rawValue: rawTarget) {
        self?.activationHandler?(target)
      }
    }
  }
}
