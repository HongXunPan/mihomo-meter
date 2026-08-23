import Combine

@MainActor
final class LaunchAtLoginController: ObservableObject {
  enum State: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable
  }

  @Published private(set) var state: State
  @Published private(set) var errorMessage: String?

  private let service: LoginItemServicing

  convenience init() {
    self.init(service: SystemLoginItemService())
  }

  init(service: LoginItemServicing) {
    self.service = service
    state = Self.mapStatus(service.status)
  }

  var isRequested: Bool {
    state == .enabled || state == .requiresApproval
  }

  var requiresApproval: Bool {
    state == .requiresApproval
  }

  var statusMessage: String {
    switch state {
    case .enabled:
      "当前用户登录后将静默启动，只显示状态栏入口。"
    case .disabled:
      "默认关闭；开启后只在当前用户登录桌面时启动。"
    case .requiresApproval:
      "需要在系统设置的“登录项”中允许 Mihomo Meter。"
    case .unavailable:
      "系统尚未找到 Mihomo Meter 登录项；可尝试开启以重新注册。"
    }
  }

  func setEnabled(_ isEnabled: Bool) {
    errorMessage = nil
    do {
      if isEnabled {
        try service.register()
      } else {
        try service.unregister()
      }
    } catch {
      errorMessage = "无法更新登录项，已恢复系统当前状态。"
    }
    reloadState()
  }

  func refresh() {
    errorMessage = nil
    reloadState()
  }

  private func reloadState() {
    state = Self.mapStatus(service.status)
  }

  func openSystemSettings() {
    service.openSystemSettings()
  }

  private static func mapStatus(_ status: LoginItemSystemStatus) -> State {
    switch status {
    case .enabled:
      .enabled
    case .notRegistered:
      .disabled
    case .requiresApproval:
      .requiresApproval
    case .notFound:
      .unavailable
    }
  }
}
