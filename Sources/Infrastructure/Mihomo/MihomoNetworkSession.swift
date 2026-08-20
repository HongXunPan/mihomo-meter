import Foundation

enum MihomoNetworkSession {
  static let shared: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    return URLSession(configuration: configuration)
  }()
}
