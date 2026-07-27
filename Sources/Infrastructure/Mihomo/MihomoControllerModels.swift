import Foundation

struct MihomoVersionResponse: Decodable, Equatable, Sendable {
  let meta: Bool
  let version: String
}

struct MihomoProxiesResponse: Decodable, Equatable, Sendable {
  let proxies: [String: MihomoProxyResponse]
}

struct MihomoProxyResponse: Decodable, Equatable, Sendable {
  let name: String
  let type: String
  let now: String?
  let all: [String]?
}

struct MihomoRuntimeConfigurationResponse: Decodable, Equatable, Sendable {
  let mode: String?
  let allowLan: Bool?
  let ipv6: Bool?
  let mixedPort: Int?
  let port: Int?
  let socksPort: Int?
  let globalUserAgent: String?
  let tun: MihomoTunConfigurationResponse?

  private enum CodingKeys: String, CodingKey {
    case mode
    case allowLan = "allow-lan"
    case ipv6
    case mixedPort = "mixed-port"
    case port
    case socksPort = "socks-port"
    case globalUserAgent = "global-ua"
    case tun
  }

  var runtimeConfiguration: MihomoRuntimeConfiguration {
    MihomoRuntimeConfiguration(
      mode: mode,
      tun: tun?.runtimeConfiguration,
      isIPv6Enabled: ipv6,
      allowsLAN: allowLan,
      mixedPort: mixedPort,
      httpPort: port,
      socksPort: socksPort,
      globalUserAgent: globalUserAgent
    )
  }
}

struct MihomoTunConfigurationResponse: Decodable, Equatable, Sendable {
  let enable: Bool?
  let stack: String?
  let autoRoute: Bool?

  private enum CodingKeys: String, CodingKey {
    case enable
    case stack
    case autoRoute = "auto-route"
  }

  var runtimeConfiguration: MihomoTunRuntimeConfiguration {
    MihomoTunRuntimeConfiguration(
      isEnabled: enable,
      stack: stack,
      automaticallyRoutesTraffic: autoRoute
    )
  }
}

struct MihomoConnectionsSnapshot: Decodable, Equatable, Sendable {
  let downloadTotal: UInt64
  let uploadTotal: UInt64
  let connections: [MihomoConnectionResponse]
}

struct MihomoConnectionResponse: Decodable, Equatable, Sendable {
  let id: String
  let upload: UInt64
  let download: UInt64
  let chains: [String]
  let providerChains: [String]
  let rule: String?

  private enum CodingKeys: String, CodingKey {
    case id
    case upload
    case download
    case chains
    case providerChains
    case rule
  }

  init(
    id: String,
    upload: UInt64,
    download: UInt64,
    chains: [String],
    providerChains: [String] = [],
    rule: String? = nil
  ) {
    self.id = id
    self.upload = upload
    self.download = download
    self.chains = chains
    self.providerChains = providerChains
    self.rule = rule
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    upload = try container.decode(UInt64.self, forKey: .upload)
    download = try container.decode(UInt64.self, forKey: .download)
    chains = try container.decodeIfPresent([String].self, forKey: .chains) ?? []
    providerChains =
      try container.decodeIfPresent([String].self, forKey: .providerChains) ?? []
    rule = try container.decodeIfPresent(String.self, forKey: .rule)
  }
}

extension MihomoConnectionsSnapshot {
  var trafficSnapshot: ConnectionTrafficSnapshot {
    ConnectionTrafficSnapshot(
      kernelTotal: TrafficBytes(upload: uploadTotal, download: downloadTotal),
      connections: connections.map {
        ConnectionTrafficSample(
          id: $0.id,
          bytes: TrafficBytes(upload: $0.upload, download: $0.download),
          chains: $0.chains,
          rule: $0.rule
        )
      }
    )
  }
}
