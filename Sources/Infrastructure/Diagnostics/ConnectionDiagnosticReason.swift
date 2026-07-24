import Foundation

enum ConnectionDiagnosticReason: Equatable, Sendable {
  case invalidEndpoint
  case authenticationFailed
  case controllerHTTP(Int)
  case controllerInvalidResponse
  case unsupportedResponse
  case controllerNetwork(URLError.Code)
  case controllerTransport
  case streamMalformedMessage
  case streamNetwork(URLError.Code)
  case streamClosed
  case keychainInvalidData
  case keychainStatus(OSStatus)
  case dataStale
  case unknown

  var logFields: String {
    switch self {
    case .invalidEndpoint:
      "reason=invalid_endpoint"
    case .authenticationFailed:
      "reason=authentication_failed"
    case .controllerHTTP(let statusCode):
      "reason=controller_http code=\(statusCode)"
    case .controllerInvalidResponse:
      "reason=controller_invalid_response"
    case .unsupportedResponse:
      "reason=unsupported_response"
    case .controllerNetwork(let code):
      "reason=controller_network code=\(code.rawValue)"
    case .controllerTransport:
      "reason=controller_transport"
    case .streamMalformedMessage:
      "reason=stream_malformed_message"
    case .streamNetwork(let code):
      "reason=stream_network code=\(code.rawValue)"
    case .streamClosed:
      "reason=stream_closed"
    case .keychainInvalidData:
      "reason=keychain_invalid_data"
    case .keychainStatus(let status):
      "reason=keychain_status code=\(status)"
    case .dataStale:
      "reason=data_stale"
    case .unknown:
      "reason=unknown"
    }
  }

  static func classify(
    _ error: any Error,
    dataWasStale: Bool = false
  ) -> ConnectionDiagnosticReason {
    if dataWasStale {
      return .dataStale
    }

    switch error {
    case let error as MihomoControllerError:
      return classify(error)
    case let error as ConnectionStreamError:
      return classify(error)
    case let error as KeychainSecretStoreError:
      return classify(error)
    case is ControllerEndpointError:
      return .invalidEndpoint
    default:
      return .unknown
    }
  }

  private static func classify(
    _ error: MihomoControllerError
  ) -> ConnectionDiagnosticReason {
    switch error {
    case .authenticationFailed:
      .authenticationFailed
    case .httpStatus(let statusCode):
      .controllerHTTP(statusCode)
    case .invalidResponse:
      .controllerInvalidResponse
    case .unsupportedResponse:
      .unsupportedResponse
    case .network(let code):
      .controllerNetwork(code)
    case .transport:
      .controllerTransport
    }
  }

  private static func classify(
    _ error: ConnectionStreamError
  ) -> ConnectionDiagnosticReason {
    switch error {
    case .malformedMessage:
      .streamMalformedMessage
    case .unsupportedResponse:
      .unsupportedResponse
    case .network(let code):
      .streamNetwork(code)
    case .closed:
      .streamClosed
    }
  }

  private static func classify(
    _ error: KeychainSecretStoreError
  ) -> ConnectionDiagnosticReason {
    switch error {
    case .invalidData:
      .keychainInvalidData
    case .unhandledStatus(let status):
      .keychainStatus(status)
    }
  }
}
