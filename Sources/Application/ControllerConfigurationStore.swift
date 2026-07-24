import Foundation

@MainActor
final class ControllerConfigurationStore {
  struct StartupConfiguration: Equatable, Sendable {
    let address: String
    let secret: String
  }

  private static let addressDefaultsKey = "controllerAddress"

  private let secretStore: any ControllerSecretStoring
  private let userDefaults: UserDefaults

  init(
    secretStore: any ControllerSecretStoring,
    userDefaults: UserDefaults
  ) {
    self.secretStore = secretStore
    self.userDefaults = userDefaults
  }

  var storedAddress: String {
    userDefaults.string(forKey: Self.addressDefaultsKey) ?? ""
  }

  func loadStartupConfiguration() async throws -> StartupConfiguration {
    StartupConfiguration(
      address: storedAddress,
      secret: try await secretStore.loadSecret(reason: .applicationStartup) ?? ""
    )
  }

  func saveValidatedSecret(_ secret: String) async throws {
    try await secretStore.saveSecret(secret, reason: .connectionValidated)
  }

  func saveValidatedAddress(_ endpoint: ControllerEndpoint) {
    userDefaults.set(
      endpoint.baseURL.absoluteString,
      forKey: Self.addressDefaultsKey
    )
  }
}
