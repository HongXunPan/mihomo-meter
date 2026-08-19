import AppKit
import XCTest

@testable import MihomoMeter

@MainActor
final class ApplicationDockVisibilityControllerTests: XCTestCase {
  func testInitializationHidesDockWhenApplicationStartsRegular() {
    let application = ActivationPolicyApplicationSpy(initialPolicy: .regular)

    _ = ApplicationDockVisibilityController(application: application)

    XCTAssertEqual(application.appliedPolicies, [.accessory])
  }

  func testDockRemainsVisibleUntilLastManagedWindowCloses() {
    let application = ActivationPolicyApplicationSpy(initialPolicy: .accessory)
    let controller = ApplicationDockVisibilityController(application: application)

    controller.windowWillPresent(.statistics)
    controller.windowWillPresent(.controllerSettings)
    controller.windowWillClose(.statistics)

    XCTAssertEqual(application.appliedPolicies, [.regular])

    controller.windowWillClose(.controllerSettings)

    XCTAssertEqual(application.appliedPolicies, [.regular, .accessory])
  }

  func testRepeatedPresentationDoesNotRepeatActivationPolicyChange() {
    let application = ActivationPolicyApplicationSpy(initialPolicy: .accessory)
    let controller = ApplicationDockVisibilityController(application: application)

    controller.windowWillPresent(.connectionAnalyticsTrend)
    controller.windowWillPresent(.connectionAnalyticsTrend)
    controller.windowWillClose(.connectionAnalyticsTrend)

    XCTAssertEqual(application.appliedPolicies, [.regular, .accessory])
  }

  func testDockIconRefreshesWheneverDockBecomesVisible() {
    let application = ActivationPolicyApplicationSpy(initialPolicy: .accessory)
    var iconRefreshCount = 0
    let controller = ApplicationDockVisibilityController(
      application: application,
      dockIconRefresher: {
        iconRefreshCount += 1
      }
    )

    controller.windowWillPresent(.statistics)
    controller.windowWillClose(.statistics)
    controller.windowWillPresent(.controllerSettings)

    XCTAssertEqual(iconRefreshCount, 2)
  }
}

@MainActor
private final class ActivationPolicyApplicationSpy: ApplicationActivationPolicyControlling {
  private var currentPolicy: NSApplication.ActivationPolicy
  private(set) var appliedPolicies: [NSApplication.ActivationPolicy] = []

  init(initialPolicy: NSApplication.ActivationPolicy) {
    currentPolicy = initialPolicy
  }

  func activationPolicy() -> NSApplication.ActivationPolicy {
    currentPolicy
  }

  func setActivationPolicy(_ activationPolicy: NSApplication.ActivationPolicy) -> Bool {
    currentPolicy = activationPolicy
    appliedPolicies.append(activationPolicy)
    return true
  }
}
