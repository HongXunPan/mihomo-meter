import Foundation

protocol MihomoControllerServing: Sendable {
  func fetchVersion(
    endpoint: ControllerEndpoint,
    secret: String
  ) async throws -> MihomoVersionResponse

  func fetchProxies(
    endpoint: ControllerEndpoint,
    secret: String
  ) async throws -> MihomoProxiesResponse

  func fetchRuntimeConfiguration(
    endpoint: ControllerEndpoint,
    secret: String
  ) async throws -> MihomoRuntimeConfiguration
}

actor MihomoControllerClient: MihomoControllerServing {
  private let session: URLSession
  private let decoder: JSONDecoder

  init(session: URLSession = .shared) {
    self.session = session
    decoder = JSONDecoder()
  }

  func fetchVersion(
    endpoint: ControllerEndpoint,
    secret: String
  ) async throws -> MihomoVersionResponse {
    try await get(
      MihomoVersionResponse.self,
      url: endpoint.httpURL(path: "/version"),
      secret: secret
    )
  }

  func fetchProxies(
    endpoint: ControllerEndpoint,
    secret: String
  ) async throws -> MihomoProxiesResponse {
    try await get(
      MihomoProxiesResponse.self,
      url: endpoint.httpURL(path: "/proxies"),
      secret: secret
    )
  }

  func fetchRuntimeConfiguration(
    endpoint: ControllerEndpoint,
    secret: String
  ) async throws -> MihomoRuntimeConfiguration {
    let response = try await get(
      MihomoRuntimeConfigurationResponse.self,
      url: endpoint.httpURL(path: "/configs"),
      secret: secret
    )
    return response.runtimeConfiguration
  }

  private func get<Response: Decodable>(
    _ responseType: Response.Type,
    url: URL,
    secret: String
  ) async throws -> Response {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 5
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    if !secret.isEmpty {
      request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
    }

    do {
      let (data, response) = try await session.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw MihomoControllerError.invalidResponse
      }

      switch httpResponse.statusCode {
      case 200..<300:
        break
      case 401, 403:
        throw MihomoControllerError.authenticationFailed
      default:
        throw MihomoControllerError.httpStatus(httpResponse.statusCode)
      }

      do {
        return try decoder.decode(responseType, from: data)
      } catch {
        throw MihomoControllerError.unsupportedResponse
      }
    } catch let error as MihomoControllerError {
      throw error
    } catch let error as URLError {
      throw MihomoControllerError.network(error.code)
    } catch {
      throw MihomoControllerError.transport
    }
  }
}

enum MihomoControllerError: Error, Equatable, LocalizedError {
  case authenticationFailed
  case httpStatus(Int)
  case invalidResponse
  case unsupportedResponse
  case network(URLError.Code)
  case transport

  var errorDescription: String? {
    switch self {
    case .authenticationFailed:
      "鉴权失败，请检查访问密钥。"
    case .httpStatus(let statusCode):
      "Mihomo 服务返回异常状态（HTTP \(statusCode)）。"
    case .invalidResponse:
      "Mihomo 服务返回了无效响应。"
    case .unsupportedResponse:
      "当前 Mihomo 响应结构暂不受支持。"
    case .network:
      "无法连接 Mihomo 服务，请检查地址和 Mihomo 状态。"
    case .transport:
      "Mihomo 服务通信失败。"
    }
  }
}
