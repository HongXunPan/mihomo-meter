import ServiceManagement

enum LoginItemSystemStatus: Equatable {
  case enabled
  case notRegistered
  case requiresApproval
  case notFound
}

@MainActor
protocol LoginItemServicing: AnyObject {
  var status: LoginItemSystemStatus { get }

  func register() throws
  func unregister() throws
  func openSystemSettings()
}

@MainActor
final class SystemLoginItemService: LoginItemServicing {
  private let service: SMAppService

  init(service: SMAppService = .mainApp) {
    self.service = service
  }

  var status: LoginItemSystemStatus {
    switch service.status {
    case .enabled:
      .enabled
    case .notRegistered:
      .notRegistered
    case .requiresApproval:
      .requiresApproval
    case .notFound:
      .notFound
    @unknown default:
      .notFound
    }
  }

  func register() throws {
    try service.register()
  }

  func unregister() throws {
    try service.unregister()
  }

  func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}
