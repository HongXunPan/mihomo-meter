import Combine
import Sparkle

@MainActor
final class SparkleAppUpdater: AppUpdating {
  private let updaterController: SPUStandardUpdaterController
  private var hasStarted = false

  init(
    updaterController: SPUStandardUpdaterController = SPUStandardUpdaterController(
      startingUpdater: false,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
  ) {
    self.updaterController = updaterController
  }

  var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> {
    updaterController.updater.publisher(for: \.canCheckForUpdates)
      .eraseToAnyPublisher()
  }

  func start() {
    guard !hasStarted else {
      return
    }
    hasStarted = true

    updaterController.startUpdater()
    if updaterController.updater.automaticallyChecksForUpdates {
      updaterController.updater.checkForUpdatesInBackground()
    }
  }

  func checkForUpdates() {
    updaterController.checkForUpdates(nil)
  }
}
