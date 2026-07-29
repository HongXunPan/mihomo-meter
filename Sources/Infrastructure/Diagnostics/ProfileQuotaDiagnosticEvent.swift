import Foundation

enum ProfileQuotaDiagnosticTrigger: String, Equatable, Sendable {
  case automatic
  case manual
}

enum ProfileQuotaDiagnosticProxyKind: String, Equatable, Sendable {
  case mixed
  case http
  case socks
}

enum ProfileQuotaDiagnosticUserAgentSource: String, Equatable, Sendable {
  case mihomoConfiguration = "mihomo_config"
  case mihomoDefault = "mihomo_default"
}

struct ProfileQuotaDiagnosticContext: Equatable, Sendable {
  private static let fingerprintPrefixLength = 12

  let requestID: UUID
  let subscriptionID: UUID
  let urlFingerprintPrefix: String?
  let trigger: ProfileQuotaDiagnosticTrigger
  let isCurrentProfile: Bool
  let proxyKind: ProfileQuotaDiagnosticProxyKind
  let userAgentSource: ProfileQuotaDiagnosticUserAgentSource

  init(
    requestID: UUID = UUID(),
    subscriptionID: UUID,
    urlFingerprint: String?,
    trigger: ProfileQuotaDiagnosticTrigger,
    isCurrentProfile: Bool,
    proxyKind: ProfileQuotaDiagnosticProxyKind,
    userAgentSource: ProfileQuotaDiagnosticUserAgentSource
  ) {
    self.requestID = requestID
    self.subscriptionID = subscriptionID
    urlFingerprintPrefix = urlFingerprint.map {
      String($0.prefix(Self.fingerprintPrefixLength))
    }
    self.trigger = trigger
    self.isCurrentProfile = isCurrentProfile
    self.proxyKind = proxyKind
    self.userAgentSource = userAgentSource
  }

  var logFields: String {
    [
      "request_id=\(requestID.uuidString.lowercased())",
      "subscription_id=\(subscriptionID.uuidString.lowercased())",
      "url_fingerprint=\(urlFingerprintPrefix ?? "none")",
      "trigger=\(trigger.rawValue)",
      "is_current=\(isCurrentProfile)",
      "proxy_kind=\(proxyKind.rawValue)",
      "user_agent_source=\(userAgentSource.rawValue)",
    ].joined(separator: " ")
  }
}

enum ProfileQuotaDiagnosticOutcome: Equatable, Sendable {
  case succeeded
  case cancelled
  case insecureSubscriptionURL
  case noAvailableMihomoProxy
  case insecureRedirect
  case invalidResponse
  case httpStatus(Int)
  case missingSubscriptionInfo(statusCode: Int)
  case invalidSubscriptionInfo
  case timedOut(timeoutSeconds: Int)
  case network(URLError.Code)
  case transport
  case storageUnavailable

  var logFields: String {
    switch self {
    case .succeeded:
      "result=succeeded"
    case .cancelled:
      "result=cancelled"
    case .insecureSubscriptionURL:
      "result=insecure_subscription_url"
    case .noAvailableMihomoProxy:
      "result=no_available_mihomo_proxy"
    case .insecureRedirect:
      "result=insecure_redirect"
    case .invalidResponse:
      "result=invalid_response"
    case .httpStatus(let statusCode):
      "result=http_status http_status=\(statusCode)"
    case .missingSubscriptionInfo(let statusCode):
      "result=missing_subscription_info http_status=\(statusCode)"
    case .invalidSubscriptionInfo:
      "result=invalid_subscription_info"
    case .timedOut(let timeoutSeconds):
      "result=network_error network_code=\(URLError.Code.timedOut.rawValue) "
        + "network_reason=timed_out timeout_seconds=\(max(timeoutSeconds, 0))"
    case .network(let code):
      "result=network_error network_code=\(code.rawValue) "
        + "network_reason=\(Self.networkReason(for: code))"
    case .transport:
      "result=transport_error"
    case .storageUnavailable:
      "result=storage_unavailable"
    }
  }

  private static func networkReason(for code: URLError.Code) -> String {
    switch code {
    case .timedOut:
      "timed_out"
    case .cannotFindHost, .dnsLookupFailed:
      "dns_failed"
    case .cannotConnectToHost:
      "cannot_connect"
    case .networkConnectionLost:
      "connection_lost"
    case .notConnectedToInternet:
      "offline"
    case .secureConnectionFailed:
      "tls_failed"
    case .cancelled:
      "cancelled"
    default:
      "other"
    }
  }
}
