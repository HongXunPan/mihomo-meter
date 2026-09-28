import CryptoKit
import Foundation

protocol ProfileURLFingerprinting: Sendable {
  func fingerprint(for url: URL) async throws -> String
  func makeSession() -> any ProfileURLFingerprintingSession
}

protocol ProfileURLFingerprintingSession: Sendable {
  func fingerprint(for url: URL) async throws -> String
}

struct HMACProfileURLFingerprinter: ProfileURLFingerprinting {
  private let keyStore: any ProfileFingerprintKeyStoring

  init(keyStore: any ProfileFingerprintKeyStoring) {
    self.keyStore = keyStore
  }

  func fingerprint(for url: URL) async throws -> String {
    try await makeSession().fingerprint(for: url)
  }

  func makeSession() -> any ProfileURLFingerprintingSession {
    HMACProfileURLFingerprintSession(keyStore: keyStore)
  }
}

private actor HMACProfileURLFingerprintSession: ProfileURLFingerprintingSession {
  private let keyStore: any ProfileFingerprintKeyStoring
  private var cachedKey: SymmetricKey?

  init(keyStore: any ProfileFingerprintKeyStoring) {
    self.keyStore = keyStore
  }

  func fingerprint(for url: URL) async throws -> String {
    let key: SymmetricKey
    if let cachedKey {
      key = cachedKey
    } else {
      key = SymmetricKey(data: try await keyStore.loadOrCreateKey())
      cachedKey = key
    }
    let normalizedURL = try ProfileURLNormalizer.normalizedString(from: url)
    let signature = HMAC<SHA256>.authenticationCode(
      for: Data(normalizedURL.utf8),
      using: key
    )
    return signature.map { String(format: "%02x", $0) }.joined()
  }
}

enum ProfileURLNormalizer {
  static func normalizedString(from url: URL) throws -> String {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw ProfileURLFingerprintError.invalidURL
    }
    components.scheme = components.scheme?.lowercased()
    components.host = components.host?.lowercased()
    components.fragment = nil

    if (components.scheme == "https" && components.port == 443)
      || (components.scheme == "http" && components.port == 80)
    {
      components.port = nil
    }
    if components.percentEncodedPath.isEmpty {
      components.percentEncodedPath = "/"
    }

    guard
      let normalized = components.string,
      components.scheme != nil,
      components.host != nil
    else {
      throw ProfileURLFingerprintError.invalidURL
    }
    return normalized
  }
}

enum ProfileURLFingerprintError: Error, Equatable, LocalizedError {
  case invalidURL

  var errorDescription: String? {
    "无法为无效的 Profile 地址生成指纹。"
  }
}
