import Foundation

actor GitHubReleaseClient: LatestAppReleaseFetching {
  private let session: URLSession
  private let latestReleaseURL: URL
  private let decoder = JSONDecoder()

  init(
    session: URLSession = .shared,
    latestReleaseURL: URL = GitHubReleaseClient.makeDefaultReleaseURL()
  ) {
    self.session = session
    self.latestReleaseURL = latestReleaseURL
  }

  func fetchLatestRelease() async throws -> AppRelease? {
    var request = URLRequest(url: latestReleaseURL)
    request.httpMethod = "GET"
    request.timeoutInterval = 10
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("MihomoMeter", forHTTPHeaderField: "User-Agent")

    do {
      let (data, response) = try await session.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw GitHubReleaseClientError.invalidResponse
      }

      switch httpResponse.statusCode {
      case 200:
        return try Self.decodeRelease(from: data, decoder: decoder)
      case 404:
        return nil
      default:
        throw GitHubReleaseClientError.httpStatus(httpResponse.statusCode)
      }
    } catch let error as GitHubReleaseClientError {
      throw error
    } catch let error as URLError {
      throw GitHubReleaseClientError.network(error.code)
    } catch {
      throw GitHubReleaseClientError.transport
    }
  }

  static func decodeRelease(
    from data: Data,
    decoder: JSONDecoder = JSONDecoder()
  ) throws -> AppRelease {
    let response: GitHubReleaseResponse
    do {
      response = try decoder.decode(GitHubReleaseResponse.self, from: data)
    } catch {
      throw GitHubReleaseClientError.invalidResponse
    }

    guard let version = SemanticVersion(response.tagName) else {
      throw GitHubReleaseClientError.invalidVersion
    }
    guard response.pageURL.scheme == "https",
      response.pageURL.host == "github.com"
    else {
      throw GitHubReleaseClientError.invalidReleaseURL
    }

    return AppRelease(version: version, pageURL: response.pageURL)
  }

  private static func makeDefaultReleaseURL() -> URL {
    guard
      let url = URL(
        string: "https://api.github.com/repos/HongXunPan/mihomo-meter/releases/latest"
      )
    else {
      preconditionFailure("固定 GitHub Release 地址无效。")
    }
    return url
  }
}

private struct GitHubReleaseResponse: Decodable {
  let tagName: String
  let pageURL: URL

  enum CodingKeys: String, CodingKey {
    case tagName = "tag_name"
    case pageURL = "html_url"
  }
}

enum GitHubReleaseClientError: Error, Equatable, LocalizedError {
  case invalidResponse
  case invalidVersion
  case invalidReleaseURL
  case httpStatus(Int)
  case network(URLError.Code)
  case transport

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      "GitHub Release 响应无效。"
    case .invalidVersion:
      "GitHub Release 版本号无效。"
    case .invalidReleaseURL:
      "GitHub Release 下载地址无效。"
    case .httpStatus(let statusCode):
      "GitHub Release 服务返回异常状态（HTTP \(statusCode)）。"
    case .network:
      "无法连接 GitHub Release 服务。"
    case .transport:
      "GitHub Release 服务通信失败。"
    }
  }
}
