import Foundation
import Security

protocol ControllerSecretStoring: Sendable {
  func loadSecret() async throws -> String?
  func saveSecret(_ secret: String) async throws
  func deleteSecret() async throws
}

actor KeychainSecretStore: ControllerSecretStoring {
  private let service: String
  private let account: String

  init(
    service: String = "com.HongXunPan.MihomoMeter.controller",
    account: String = "default"
  ) {
    self.service = service
    self.account = account
  }

  func loadSecret() async throws -> String? {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      guard let data = result as? Data,
        let secret = String(data: data, encoding: .utf8)
      else {
        throw KeychainSecretStoreError.invalidData
      }
      return secret
    case errSecItemNotFound:
      return nil
    default:
      throw KeychainSecretStoreError.unhandledStatus(status)
    }
  }

  func saveSecret(_ secret: String) async throws {
    guard !secret.isEmpty else {
      try await deleteSecret()
      return
    }

    let secretData = Data(secret.utf8)
    let status = SecItemUpdate(
      baseQuery() as CFDictionary,
      [kSecValueData as String: secretData] as CFDictionary
    )

    switch status {
    case errSecSuccess:
      return
    case errSecItemNotFound:
      var attributes = baseQuery()
      attributes[kSecValueData as String] = secretData
      let addStatus = SecItemAdd(attributes as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw KeychainSecretStoreError.unhandledStatus(addStatus)
      }
    default:
      throw KeychainSecretStoreError.unhandledStatus(status)
    }
  }

  func deleteSecret() async throws {
    let status = SecItemDelete(baseQuery() as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainSecretStoreError.unhandledStatus(status)
    }
  }

  private func baseQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}

enum KeychainSecretStoreError: Error, Equatable, LocalizedError {
  case invalidData
  case unhandledStatus(OSStatus)

  var errorDescription: String? {
    switch self {
    case .invalidData:
      "Keychain 中的 Secret 数据无效。"
    case .unhandledStatus(let status):
      "Keychain 操作失败（\(status)）。"
    }
  }
}
