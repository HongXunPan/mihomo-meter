import Combine
import Foundation

@MainActor
protocol AppUpdating: AnyObject {
  var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> { get }

  func start()
  func checkForUpdates()
}

@MainActor
final class AppUpdateModel: ObservableObject {
  @Published private(set) var canCheckForUpdates = false

  let currentVersionText: String

  private let updater: any AppUpdating

  convenience init() {
    self.init(
      currentVersionString: Self.bundleVersion(),
      updater: SparkleAppUpdater()
    )
  }

  init(
    currentVersionString: String,
    updater: any AppUpdating
  ) {
    currentVersionText = currentVersionString
    self.updater = updater

    updater.canCheckForUpdatesPublisher
      .assign(to: &$canCheckForUpdates)
  }

  func start() {
    updater.start()
  }

  func checkForUpdates() {
    updater.checkForUpdates()
  }

  private static func bundleVersion(bundle: Bundle = .main) -> String {
    bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "开发版"
  }
}
