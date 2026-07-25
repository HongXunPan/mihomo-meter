import Combine
import XCTest

@testable import MihomoMeter

@MainActor
final class AppUpdateModelTests: XCTestCase {
  func testStartsUpdaterAndForwardsManualCheck() {
    let updater = AppUpdateTestUpdater()
    let model = AppUpdateModel(
      currentVersionString: "1.2.3",
      updater: updater
    )

    model.start()
    model.checkForUpdates()

    XCTAssertEqual(model.currentVersionText, "1.2.3")
    XCTAssertEqual(updater.startCallCount, 1)
    XCTAssertEqual(updater.checkCallCount, 1)
  }

  func testReflectsUpdaterAvailability() {
    let updater = AppUpdateTestUpdater()
    let model = AppUpdateModel(
      currentVersionString: "1.2.3",
      updater: updater
    )

    XCTAssertFalse(model.canCheckForUpdates)

    updater.setCanCheckForUpdates(true)

    XCTAssertTrue(model.canCheckForUpdates)
  }
}

@MainActor
private final class AppUpdateTestUpdater: AppUpdating {
  private let canCheckForUpdatesSubject = CurrentValueSubject<Bool, Never>(false)

  private(set) var startCallCount = 0
  private(set) var checkCallCount = 0

  var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> {
    canCheckForUpdatesSubject.eraseToAnyPublisher()
  }

  func start() {
    startCallCount += 1
  }

  func checkForUpdates() {
    checkCallCount += 1
  }

  func setCanCheckForUpdates(_ canCheckForUpdates: Bool) {
    canCheckForUpdatesSubject.send(canCheckForUpdates)
  }
}
