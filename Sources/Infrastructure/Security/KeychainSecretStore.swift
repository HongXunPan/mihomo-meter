import Foundation
import Security

protocol ControllerSecretStoring: Sendable {
  func loadSecret(reason: KeychainAccessReason) async throws -> String?
  func saveSecret(_ secret: String, reason: KeychainAccessReason) async throws
  func deleteSecret(reason: KeychainAccessReason) async throws
}

actor KeychainSecretStore: ControllerSecretStoring {
  private let service: String
  private let account: String
  private let diagnosticLogger: any AppDiagnosticLogging
  private let clock = ContinuousClock()

  init(
    service: String = "com.HongXunPan.MihomoMeter.controller",
    account: String = "default",
    diagnosticLogger: any AppDiagnosticLogging = DebugDiagnosticLogger.shared
  ) {
    self.service = service
    self.account = account
    self.diagnosticLogger = diagnosticLogger
  }

  func loadSecret(reason: KeychainAccessReason) async throws -> String? {
    let startedAt = clock.now
    let context = KeychainDiagnosticContext(operation: .load, reason: reason)
    await diagnosticLogger.record(.keychainOperationStarted(context))

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
        await recordCompletion(
          context: context,
          outcome: .invalidData,
          startedAt: startedAt
        )
        throw KeychainSecretStoreError.invalidData
      }
      await recordCompletion(
        context: context,
        outcome: .loaded,
        startedAt: startedAt
      )
      return secret
    case errSecItemNotFound:
      await recordCompletion(
        context: context,
        outcome: .notFound,
        startedAt: startedAt
      )
      return nil
    default:
      await recordCompletion(
        context: context,
        outcome: .failed(status),
        startedAt: startedAt
      )
      throw KeychainSecretStoreError.unhandledStatus(status)
    }
  }

  func saveSecret(_ secret: String, reason: KeychainAccessReason) async throws {
    guard !secret.isEmpty else {
      try await deleteSecret(reason: .validatedEmptyAccessKey)
      return
    }

    let startedAt = clock.now
    let context = KeychainDiagnosticContext(operation: .save, reason: reason)
    await diagnosticLogger.record(.keychainOperationStarted(context))

    let secretData = Data(secret.utf8)
    let status = SecItemUpdate(
      baseQuery() as CFDictionary,
      [kSecValueData as String: secretData] as CFDictionary
    )

    switch status {
    case errSecSuccess:
      await recordCompletion(
        context: context,
        outcome: .updated,
        startedAt: startedAt
      )
      return
    case errSecItemNotFound:
      var attributes = baseQuery()
      attributes[kSecValueData as String] = secretData
      let addStatus = SecItemAdd(attributes as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        await recordCompletion(
          context: context,
          outcome: .failed(addStatus),
          startedAt: startedAt
        )
        throw KeychainSecretStoreError.unhandledStatus(addStatus)
      }
      await recordCompletion(
        context: context,
        outcome: .created,
        startedAt: startedAt
      )
    default:
      await recordCompletion(
        context: context,
        outcome: .failed(status),
        startedAt: startedAt
      )
      throw KeychainSecretStoreError.unhandledStatus(status)
    }
  }

  func deleteSecret(reason: KeychainAccessReason) async throws {
    let startedAt = clock.now
    let context = KeychainDiagnosticContext(operation: .delete, reason: reason)
    await diagnosticLogger.record(.keychainOperationStarted(context))

    let status = SecItemDelete(baseQuery() as CFDictionary)
    switch status {
    case errSecSuccess:
      await recordCompletion(
        context: context,
        outcome: .deleted,
        startedAt: startedAt
      )
    case errSecItemNotFound:
      await recordCompletion(
        context: context,
        outcome: .alreadyMissing,
        startedAt: startedAt
      )
    default:
      await recordCompletion(
        context: context,
        outcome: .failed(status),
        startedAt: startedAt
      )
      throw KeychainSecretStoreError.unhandledStatus(status)
    }
  }

  private func baseQuery() -> [String: Any] {
    Self.makeBaseQuery(service: service, account: account)
  }

  static func makeBaseQuery(
    service: String,
    account: String
  ) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecUseDataProtectionKeychain as String: true,
    ]
  }

  private func recordCompletion(
    context: KeychainDiagnosticContext,
    outcome: KeychainDiagnosticOutcome,
    startedAt: ContinuousClock.Instant
  ) async {
    let components = startedAt.duration(to: clock.now).components
    let elapsedMilliseconds =
      components.seconds * 1_000
      + components.attoseconds / 1_000_000_000_000_000

    await diagnosticLogger.record(
      .keychainOperationFinished(
        context,
        outcome: outcome,
        elapsedMilliseconds: Int(elapsedMilliseconds)
      )
    )
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
