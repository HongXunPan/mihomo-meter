import CFNetwork
import Foundation

protocol ActiveQuotaQuerying: Sendable {
  func query(
    subscriptionURL: URL,
    via proxy: MihomoLocalProxy,
    userAgent: String
  ) async throws -> ActiveQuotaQueryResult
}

struct MihomoActiveQuotaQueryClient: ActiveQuotaQuerying {
  private let timeout: TimeInterval

  init(timeout: TimeInterval = 15) {
    self.timeout = timeout
  }

  func query(
    subscriptionURL: URL,
    via proxy: MihomoLocalProxy,
    userAgent: String
  ) async throws -> ActiveQuotaQueryResult {
    guard subscriptionURL.scheme?.lowercased() == "https" else {
      throw ActiveQuotaQueryError.insecureSubscriptionURL
    }

    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    configuration.connectionProxyDictionary = proxy.connectionProxyDictionary

    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }

    let request = makeRequest(subscriptionURL: subscriptionURL, userAgent: userAgent)

    do {
      let (bytes, response) = try await session.bytes(
        for: request,
        delegate: HTTPSSubscriptionRedirectDelegate.shared
      )
      defer { bytes.task.cancel() }
      guard let response = response as? HTTPURLResponse else {
        throw ActiveQuotaQueryError.invalidResponse
      }
      guard response.url?.scheme?.lowercased() == "https" else {
        throw ActiveQuotaQueryError.insecureRedirect
      }
      guard (200..<300).contains(response.statusCode) else {
        if (300..<400).contains(response.statusCode) {
          throw ActiveQuotaQueryError.insecureRedirect
        }
        throw ActiveQuotaQueryError.httpStatus(response.statusCode)
      }
      guard let headerValue = subscriptionUserInfoHeader(in: response) else {
        throw ActiveQuotaQueryError.missingSubscriptionUserInfo(
          statusCode: response.statusCode
        )
      }
      return try SubscriptionUserInfoParser().parse(headerValue)
    } catch let error as ActiveQuotaQueryError {
      throw error
    } catch let error as URLError {
      throw ActiveQuotaQueryError.network(error.code)
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw ActiveQuotaQueryError.transport
    }
  }

  func makeRequest(subscriptionURL: URL, userAgent: String) -> URLRequest {
    var request = URLRequest(url: subscriptionURL)
    request.httpMethod = "GET"
    request.timeoutInterval = timeout
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    return request
  }

  func subscriptionUserInfoHeader(in response: HTTPURLResponse) -> String? {
    if let standardValue = response.value(forHTTPHeaderField: "Subscription-Userinfo") {
      return standardValue
    }

    return response.allHeaderFields
      .compactMap { key, value -> (name: String, value: String)? in
        guard
          let name = key as? String,
          name.lowercased().hasSuffix("-subscription-userinfo"),
          let value = value as? String
        else {
          return nil
        }
        return (name.lowercased(), value)
      }
      .sorted { $0.name < $1.name }
      .first?.value
  }
}

enum ActiveQuotaQueryError: Error, Equatable, LocalizedError, Sendable {
  case insecureSubscriptionURL
  case noAvailableMihomoProxy
  case insecureRedirect
  case invalidResponse
  case httpStatus(Int)
  case missingSubscriptionUserInfo(statusCode: Int)
  case invalidSubscriptionUserInfo
  case network(URLError.Code)
  case transport

  var errorDescription: String? {
    switch self {
    case .insecureSubscriptionURL:
      "只支持通过 HTTPS 查询订阅配额。"
    case .noAvailableMihomoProxy:
      "当前 Mihomo 没有暴露可用的本地代理端口。"
    case .insecureRedirect:
      "订阅查询重定向到了非 HTTPS 地址，已停止请求。"
    case .invalidResponse:
      "机场返回了无效响应。"
    case .httpStatus(let statusCode):
      "机场返回异常状态（HTTP \(statusCode)）。"
    case .missingSubscriptionUserInfo:
      "机场响应未包含有效配额信息。"
    case .invalidSubscriptionUserInfo:
      "机场返回的配额格式暂不受支持。"
    case .network:
      "通过 Mihomo 查询机场配额失败。"
    case .transport:
      "订阅配额查询通信失败。"
    }
  }
}

private final class HTTPSSubscriptionRedirectDelegate: NSObject, URLSessionTaskDelegate {
  static let shared = HTTPSSubscriptionRedirectDelegate()

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    let isHTTPS = request.url?.scheme?.lowercased() == "https"
    completionHandler(isHTTPS ? request : nil)
  }
}

extension MihomoLocalProxy {
  fileprivate var connectionProxyDictionary: [AnyHashable: Any] {
    switch kind {
    case .mixed, .http:
      [
        kCFNetworkProxiesHTTPEnable as String: true,
        kCFNetworkProxiesHTTPProxy as String: host,
        kCFNetworkProxiesHTTPPort as String: port,
        kCFNetworkProxiesHTTPSEnable as String: true,
        kCFNetworkProxiesHTTPSProxy as String: host,
        kCFNetworkProxiesHTTPSPort as String: port,
      ]
    case .socks:
      [
        kCFNetworkProxiesSOCKSEnable as String: true,
        kCFNetworkProxiesSOCKSProxy as String: host,
        kCFNetworkProxiesSOCKSPort as String: port,
      ]
    }
  }
}
