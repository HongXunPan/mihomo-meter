import Foundation

enum MihomoLocalProxyKind: Equatable, Sendable {
  case mixed
  case http
  case socks
}

struct MihomoLocalProxy: Equatable, Sendable {
  let host: String
  let port: Int
  let kind: MihomoLocalProxyKind

  init?(
    endpoint: ControllerEndpoint,
    runtimeConfiguration: MihomoRuntimeConfiguration
  ) {
    guard let host = endpoint.baseURL.host() else {
      return nil
    }

    let candidate: (port: Int?, kind: MihomoLocalProxyKind)
    if runtimeConfiguration.mixedPort.map(Self.isValidPort) == true {
      candidate = (runtimeConfiguration.mixedPort, .mixed)
    } else if runtimeConfiguration.httpPort.map(Self.isValidPort) == true {
      candidate = (runtimeConfiguration.httpPort, .http)
    } else {
      candidate = (runtimeConfiguration.socksPort, .socks)
    }

    guard let port = candidate.port, Self.isValidPort(port) else {
      return nil
    }
    self.host = host
    self.port = port
    kind = candidate.kind
  }

  private static func isValidPort(_ port: Int) -> Bool {
    (1...65_535).contains(port)
  }
}
