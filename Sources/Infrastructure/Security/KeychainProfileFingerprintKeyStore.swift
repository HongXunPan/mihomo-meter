import Foundation
import Security

protocol ProfileFingerprintKeyStoring: Sendable {
  func loadOrCreateKey() async throws -> Data
}

actor KeychainProfileFingerprintKeyStore: ProfileFingerprintKeyStoring {
  private static let keyLength = 32

  private let service: String
  private let account: String

  init(
    service: String = "com.HongXunPan.MihomoMeter.profile-fingerprint",
    account: String = "default"
  ) {
    self.service = service
    self.account = account
  }

  func loadOrCreateKey() async throws -> Data {
    if let key = try loadKey() {
      return key
    }

    let key = try makeRandomKey()
    var attributes = baseQuery()
    attributes[kSecValueData as String] = key
    let status = SecItemAdd(attributes as CFDictionary, nil)

    if status == errSecDuplicateItem, let stored = try loadKey() {
      return stored
    }
    guard status == errSecSuccess else {
      throw ProfileFingerprintKeyStoreError.unhandledStatus(status)
    }
    return key
  }

  private func loadKey() throws -> Data? {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    switch status {
    case errSecSuccess:
      guard let data = result as? Data, data.count == Self.keyLength else {
        throw ProfileFingerprintKeyStoreError.invalidData
      }
      return data
    case errSecItemNotFound:
      return nil
    default:
      throw ProfileFingerprintKeyStoreError.unhandledStatus(status)
    }
  }

  private func makeRandomKey() throws -> Data {
    var data = Data(count: Self.keyLength)
    let status = data.withUnsafeMutableBytes { buffer in
      SecRandomCopyBytes(kSecRandomDefault, Self.keyLength, buffer.baseAddress!)
    }
    guard status == errSecSuccess else {
      throw ProfileFingerprintKeyStoreError.unhandledStatus(status)
    }
    return data
  }

  private func baseQuery() -> [String: Any] {
    KeychainSecretStore.makeBaseQuery(service: service, account: account)
  }
}

enum ProfileFingerprintKeyStoreError: Error, Equatable, LocalizedError {
  case invalidData
  case unhandledStatus(OSStatus)

  var errorDescription: String? {
    switch self {
    case .invalidData:
      "Profile 指纹密钥数据无效。"
    case .unhandledStatus(let status):
      "Profile 指纹密钥操作失败（\(status)）。"
    }
  }
}
