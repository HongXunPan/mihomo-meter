import Combine
import Foundation

@MainActor
final class SystemNotificationController: ObservableObject {
  @Published private(set) var isEnabled: Bool
  @Published private(set) var disconnectAlertsEnabled: Bool
  @Published private(set) var authorization = SystemNotificationAuthorization.unknown
  @Published private(set) var errorMessage: String?

  private static let quotaKeyPrefix = "quota|"

  private let runtimeController: RuntimeQuotaTrackingController
  private let profileController: ProfileQuotaTrackingController
  private let monitor: TrafficMonitor
  private let client: any SystemNotificationDelivering
  private let preferenceStore: any SystemNotificationPreferenceStoring
  private let now: @MainActor () -> Date

  private var deliveredKeys: Set<String>
  private var inFlightKeys: Set<String> = []
  private var latestRuntimeSnapshot = RuntimeQuotaTrackingSnapshot.empty
  private var latestProfileSnapshot = ProfileQuotaTrackingSnapshot.empty
  private var cancellables: Set<AnyCancellable> = []

  private lazy var disconnectionTracker = SustainedDisconnectionNotificationTracker(
    now: now,
    sustainedDisconnection: { [weak self] in
      self?.handleSustainedDisconnection()
    },
    connectionRecovered: { [weak self] in
      self?.clearDisconnectionDelivery()
    }
  )

  init(
    runtimeController: RuntimeQuotaTrackingController,
    profileController: ProfileQuotaTrackingController,
    monitor: TrafficMonitor,
    client: any SystemNotificationDelivering,
    preferenceStore: any SystemNotificationPreferenceStoring =
      UserDefaultsSystemNotificationPreferenceStore(),
    now: @escaping @MainActor () -> Date = Date.init
  ) {
    self.runtimeController = runtimeController
    self.profileController = profileController
    self.monitor = monitor
    self.client = client
    self.preferenceStore = preferenceStore
    self.now = now
    let preferences = preferenceStore.load()
    isEnabled = preferences.isEnabled
    disconnectAlertsEnabled = preferences.disconnectAlertsEnabled
    deliveredKeys = preferences.deliveredKeys
  }

  var statusMessage: String {
    guard isEnabled else {
      return "系统通知默认关闭；开启后才会请求 macOS 通知权限。"
    }
    switch authorization {
    case .authorized:
      return "系统通知已开启；锁屏内容只使用通用描述。"
    case .denied:
      return "macOS 已禁止通知，请在系统设置中允许 Mihomo Meter 通知。"
    case .notDetermined:
      return "等待 macOS 通知权限确认。"
    case .unknown:
      return "正在读取 macOS 通知权限。"
    }
  }

  func start() {
    guard cancellables.isEmpty else {
      return
    }

    Publishers.CombineLatest(runtimeController.$snapshot, profileController.$snapshot)
      .sink { [weak self] runtime, profiles in
        guard let self else {
          return
        }
        latestRuntimeSnapshot = runtime
        latestProfileSnapshot = profiles
        evaluateQuota()
      }
      .store(in: &cancellables)

    Publishers.CombineLatest(
      monitor.connectionStatePublisher,
      monitor.connectionExpectationPublisher
    )
    .sink { [weak self] state, expected in
      guard let self else {
        return
      }
      disconnectionTracker.update(
        state: state,
        expected: expected,
        hasValidatedConfiguration: monitor.hasValidatedControllerConfiguration
      )
    }
    .store(in: &cancellables)

    refreshAuthorization()
  }

  func stop() {
    disconnectionTracker.stop()
    cancellables.removeAll()
  }

  func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
    preferenceStore.saveEnabled(enabled)
    errorMessage = nil
    if enabled {
      Task { [weak self] in
        await self?.requestAuthorization()
      }
    }
  }

  func setDisconnectAlertsEnabled(_ enabled: Bool) {
    disconnectAlertsEnabled = enabled
    preferenceStore.saveDisconnectAlertsEnabled(enabled)
    errorMessage = nil
    if enabled {
      disconnectionTracker.evaluateNow()
    }
  }

  func refreshAuthorization() {
    Task { [weak self] in
      guard let self else {
        return
      }
      authorization = await client.authorizationStatus()
      if authorization == .authorized {
        evaluateQuota()
        disconnectionTracker.evaluateNow()
      }
    }
  }

  private func requestAuthorization() async {
    do {
      authorization = try await client.requestAuthorization()
      if authorization == .authorized {
        evaluateQuota()
        disconnectionTracker.evaluateNow()
      }
    } catch {
      authorization = await client.authorizationStatus()
      errorMessage = "系统通知权限请求失败，请稍后重试。"
    }
  }

  private func evaluateQuota() {
    let currentDate = now()
    let inputs = SystemNotificationInputBuilder.inputs(
      runtime: latestRuntimeSnapshot,
      profiles: latestProfileSnapshot
    )
    let deliveries = QuotaSystemNotificationPolicy.deliveries(
      for: inputs,
      at: currentDate
    )
    let activeKeys = Set(deliveries.map(\.deduplicationKey))
    let originalKeys = deliveredKeys
    deliveredKeys = deliveredKeys.filter { key in
      !key.hasPrefix(Self.quotaKeyPrefix) || activeKeys.contains(key)
    }
    if deliveredKeys != originalKeys {
      persistDeliveredKeys()
    }
    guard canDeliver else {
      return
    }
    deliveries.forEach(deliverIfNeeded)
  }

  private func handleSustainedDisconnection() {
    guard disconnectAlertsEnabled, canDeliver else {
      return
    }
    deliverIfNeeded(ConnectionSystemNotificationPolicy.delivery)
  }

  private func clearDisconnectionDelivery() {
    if deliveredKeys.remove(ConnectionSystemNotificationPolicy.deduplicationKey) != nil {
      persistDeliveredKeys()
    }
  }

  private var canDeliver: Bool {
    isEnabled && authorization == .authorized
  }

  private func deliverIfNeeded(_ delivery: SystemNotificationDelivery) {
    let key = delivery.deduplicationKey
    guard !deliveredKeys.contains(key), !inFlightKeys.contains(key) else {
      return
    }
    inFlightKeys.insert(key)
    Task { [weak self] in
      guard let self else {
        return
      }
      do {
        try await client.deliver(delivery)
        deliveredKeys.insert(key)
        persistDeliveredKeys()
      } catch {
        errorMessage = "系统通知投递失败；监控和配额采集不受影响。"
      }
      inFlightKeys.remove(key)
    }
  }

  private func persistDeliveredKeys() {
    preferenceStore.saveDeliveredKeys(deliveredKeys)
  }
}
