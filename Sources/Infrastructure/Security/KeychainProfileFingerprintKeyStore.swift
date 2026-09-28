import Foundation
import Security

protocol ProfileFingerprintKeyStoring: Sendable {
  func loadOrCreateKey() async throws -> Data
}

actor KeychainProfileFingerprintKeyStore: ProfileFingerprintKeyStoring {
  private static let keyLength = 32

  private let service: String
  private let account: String
  private let diagnosticLogger: any AppDiagnosticLogging
  private let clock = ContinuousClock()

  init(
    service: String = "com.HongXunPan.MihomoMeter.profile-fingerprint",
    account: String = "default",
    diagnosticLogger: any AppDiagnosticLogging = AppDiagnosticLogger.shared
  ) {
    self.service = service
    self.account = account
    self.diagnosticLogger = diagnosticLogger
  }

  func loadOrCreateKey() async throws -> Data {
    if let key = try await loadKey() {
      return key
    }

    let key = try makeRandomKey()
    var attributes = baseQuery()
    attributes[kSecValueData as String] = key
    let startedAt = clock.now
    let requestID = UUID()
    await diagnosticLogger.record(
      .profileFingerprintKeyOperationStarted(requestID: requestID, operation: .create)
    )
    let status = SecItemAdd(attributes as CFDictionary, nil)

    switch status {
    case errSecSuccess:
      await recordCompletion(
        requestID: requestID,
        operation: .create,
        outcome: .created,
        startedAt: startedAt
      )
      return key
    case errSecDuplicateItem:
      await recordCompletion(
        requestID: requestID,
        operation: .create,
        outcome: .failed(status),
        startedAt: startedAt
      )
      if let stored = try await loadKey() {
        return stored
      }
      throw ProfileFingerprintKeyStoreError.unhandledStatus(status)
    default:
      await recordCompletion(
        requestID: requestID,
        operation: .create,
        outcome: .failed(status),
        startedAt: startedAt
      )
      throw ProfileFingerprintKeyStoreError.unhandledStatus(status)
    }
  }

  private func loadKey() async throws -> Data? {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    let startedAt = clock.now
    let requestID = UUID()
    await diagnosticLogger.record(
      .profileFingerprintKeyOperationStarted(requestID: requestID, operation: .load)
    )
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    switch status {
    case errSecSuccess:
      guard let data = result as? Data, data.count == Self.keyLength else {
        await recordCompletion(
          requestID: requestID,
          operation: .load,
          outcome: .invalidData,
          startedAt: startedAt
        )
        throw ProfileFingerprintKeyStoreError.invalidData
      }
      await recordCompletion(
        requestID: requestID,
        operation: .load,
        outcome: .loaded,
        startedAt: startedAt
      )
      return data
    case errSecItemNotFound:
      await recordCompletion(
        requestID: requestID,
        operation: .load,
        outcome: .notFound,
        startedAt: startedAt
      )
      return nil
    default:
      await recordCompletion(
        requestID: requestID,
        operation: .load,
        outcome: .failed(status),
        startedAt: startedAt
      )
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

  private func recordCompletion(
    requestID: UUID,
    operation: KeychainDiagnosticOperation,
    outcome: KeychainDiagnosticOutcome,
    startedAt: ContinuousClock.Instant
  ) async {
    let components = startedAt.duration(to: clock.now).components
    let elapsedMilliseconds =
      components.seconds * 1_000
      + components.attoseconds / 1_000_000_000_000_000

    await diagnosticLogger.record(
      .profileFingerprintKeyOperationFinished(
        requestID: requestID,
        operation: operation,
        outcome: outcome,
        elapsedMilliseconds: Int(elapsedMilliseconds)
      )
    )
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
