import Foundation

struct ControllerEndpoint: Equatable, Sendable {
  let baseURL: URL

  init(address: String) throws {
    let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedAddress.isEmpty else {
      throw ControllerEndpointError.emptyAddress
    }

    let addressWithScheme =
      trimmedAddress.contains("://")
      ? trimmedAddress
      : "http://\(trimmedAddress)"

    guard var components = URLComponents(string: addressWithScheme) else {
      throw ControllerEndpointError.invalidAddress
    }

    guard let scheme = components.scheme?.lowercased(),
      scheme == "http" || scheme == "https"
    else {
      throw ControllerEndpointError.unsupportedScheme
    }

    guard components.user == nil,
      components.password == nil,
      components.query == nil,
      components.fragment == nil
    else {
      throw ControllerEndpointError.invalidAddress
    }

    guard
      let host = components.host?.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        .lowercased(),
      host == "127.0.0.1" || host == "::1"
    else {
      throw ControllerEndpointError.nonLoopbackAddress
    }

    guard let port = components.port, (1...65_535).contains(port) else {
      throw ControllerEndpointError.missingOrInvalidPort
    }

    guard components.path.isEmpty || components.path == "/" else {
      throw ControllerEndpointError.unsupportedPath
    }

    components.scheme = scheme
    components.path = ""

    guard let normalizedURL = components.url else {
      throw ControllerEndpointError.invalidAddress
    }

    baseURL = normalizedURL
  }

  func httpURL(path: String) throws -> URL {
    try url(path: path, scheme: baseURL.scheme)
  }

  func webSocketURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
    let scheme = baseURL.scheme == "https" ? "wss" : "ws"
    return try url(path: path, scheme: scheme, queryItems: queryItems)
  }

  private func url(
    path: String,
    scheme: String?,
    queryItems: [URLQueryItem] = []
  ) throws -> URL {
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      throw ControllerEndpointError.invalidAddress
    }

    components.scheme = scheme
    components.path = path.hasPrefix("/") ? path : "/\(path)"
    components.queryItems = queryItems.isEmpty ? nil : queryItems

    guard let result = components.url else {
      throw ControllerEndpointError.invalidAddress
    }

    return result
  }
}

enum ControllerEndpointError: Error, Equatable, LocalizedError {
  case emptyAddress
  case invalidAddress
  case unsupportedScheme
  case nonLoopbackAddress
  case missingOrInvalidPort
  case unsupportedPath

  var errorDescription: String? {
    switch self {
    case .emptyAddress:
      "请输入 Mihomo 服务地址。"
    case .invalidAddress:
      "Mihomo 服务地址格式无效。"
    case .unsupportedScheme:
      "Mihomo 服务地址只支持 HTTP 或 HTTPS。"
    case .nonLoopbackAddress:
      "MVP-1 只允许连接 127.0.0.1 或 ::1。"
    case .missingOrInvalidPort:
      "Mihomo 服务地址必须包含有效端口。"
    case .unsupportedPath:
      "Mihomo 服务地址不能包含额外路径。"
    }
  }
}
