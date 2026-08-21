import XCTest

@testable import MihomoMeter

@MainActor
final class LaunchAtLoginControllerTests: XCTestCase {
  func testMapsSystemStatusAtInitialization() {
    let service = LoginItemServiceSpy(status: .requiresApproval)
    let controller = LaunchAtLoginController(service: service)

    XCTAssertEqual(controller.state, .requiresApproval)
    XCTAssertTrue(controller.isRequested)
    XCTAssertTrue(controller.canToggle)
  }

  func testEnablingRegistersAndRefreshesState() {
    let service = LoginItemServiceSpy(status: .notRegistered)
    service.statusAfterRegister = .enabled
    let controller = LaunchAtLoginController(service: service)

    controller.setEnabled(true)

    XCTAssertEqual(service.registerCallCount, 1)
    XCTAssertEqual(controller.state, .enabled)
    XCTAssertNil(controller.errorMessage)
  }

  func testDisablingUnregistersPendingApproval() {
    let service = LoginItemServiceSpy(status: .requiresApproval)
    service.statusAfterUnregister = .notRegistered
    let controller = LaunchAtLoginController(service: service)

    controller.setEnabled(false)

    XCTAssertEqual(service.unregisterCallCount, 1)
    XCTAssertEqual(controller.state, .disabled)
  }

  func testOperationFailureRestoresSystemState() {
    let service = LoginItemServiceSpy(status: .notRegistered)
    service.operationError = LoginItemTestError.failed
    let controller = LaunchAtLoginController(service: service)

    controller.setEnabled(true)

    XCTAssertEqual(controller.state, .disabled)
    XCTAssertNotNil(controller.errorMessage)
  }

  func testRefreshObservesExternalSystemChange() {
    let service = LoginItemServiceSpy(status: .notRegistered)
    let controller = LaunchAtLoginController(service: service)
    service.status = .enabled

    controller.refresh()

    XCTAssertEqual(controller.state, .enabled)
  }
}

private enum LoginItemTestError: Error {
  case failed
}

@MainActor
private final class LoginItemServiceSpy: LoginItemServicing {
  var status: LoginItemSystemStatus
  var statusAfterRegister: LoginItemSystemStatus?
  var statusAfterUnregister: LoginItemSystemStatus?
  var operationError: Error?

  private(set) var registerCallCount = 0
  private(set) var unregisterCallCount = 0

  init(status: LoginItemSystemStatus) {
    self.status = status
  }

  func register() throws {
    registerCallCount += 1
    if let operationError {
      throw operationError
    }
    if let statusAfterRegister {
      status = statusAfterRegister
    }
  }

  func unregister() throws {
    unregisterCallCount += 1
    if let operationError {
      throw operationError
    }
    if let statusAfterUnregister {
      status = statusAfterUnregister
    }
  }

  func openSystemSettings() {}
}
