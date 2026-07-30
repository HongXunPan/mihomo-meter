import Darwin
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
  let metadata: ConnectionMetadata
  let startedAt: Date?

  private enum CodingKeys: String, CodingKey {
    case id
    case upload
    case download
    case chains
    case providerChains
    case rule
    case metadata
    case start
  }

  init(
    id: String,
    upload: UInt64,
    download: UInt64,
    chains: [String],
    providerChains: [String] = [],
    rule: String? = nil,
    metadata: ConnectionMetadata = .unavailable,
    startedAt: Date? = nil
  ) {
    self.id = id
    self.upload = upload
    self.download = download
    self.chains = chains
    self.providerChains = providerChains
    self.rule = rule
    self.metadata = metadata
    self.startedAt = startedAt
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
    let metadata = try? container.decode(MihomoConnectionMetadataResponse.self, forKey: .metadata)
    self.metadata = metadata?.metadata ?? .unavailable
    startedAt = Self.decodeStartDate(from: container)
  }

  private static func decodeStartDate(
    from container: KeyedDecodingContainer<CodingKeys>
  ) -> Date? {
    guard let value = try? container.decode(String.self, forKey: .start) else {
      return nil
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) {
      return date
    }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }
}

private struct MihomoConnectionMetadataResponse: Decodable {
  let metadata: ConnectionMetadata

  private enum CodingKeys: String, CodingKey {
    case host
    case sniffHost
    case process
    case processPath
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let host = try? container.decode(String.self, forKey: .host)
    let sniffHost = try? container.decode(String.self, forKey: .sniffHost)
    let process = try? container.decode(String.self, forKey: .process)
    let processPath = try? container.decode(String.self, forKey: .processPath)
    metadata = ConnectionMetadata(
      hostname: Self.normalizedHostname(host) ?? Self.normalizedHostname(sniffHost),
      applicationName: Self.applicationName(process) ?? Self.fileName(from: processPath)
    )
  }

  private static func normalized(_ value: String?) -> String? {
    guard let value else {
      return nil
    }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty, normalized.utf8.count <= 2_048 else {
      return nil
    }
    return normalized
  }

  private static func fileName(from path: String?) -> String? {
    guard let normalizedPath = normalized(path) else {
      return nil
    }
    return normalizedPath.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.flatMap {
      normalized(String($0))
    }
  }

  private static func applicationName(_ value: String?) -> String? {
    guard let normalizedValue = normalized(value) else {
      return nil
    }
    if normalizedValue.contains("/") || normalizedValue.contains("\\") {
      return fileName(from: normalizedValue)
    }
    return normalizedValue
  }

  private static func normalizedHostname(_ value: String?) -> String? {
    guard let hostname = normalized(value), !isIPAddress(hostname) else {
      return nil
    }
    return hostname
  }

  private static func isIPAddress(_ value: String) -> Bool {
    let candidate = value.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    var ipv4 = in_addr()
    if candidate.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 {
      return true
    }
    var ipv6 = in6_addr()
    return candidate.withCString { inet_pton(AF_INET6, $0, &ipv6) } == 1
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
          rule: $0.rule,
          metadata: $0.metadata,
          startedAt: $0.startedAt
        )
      }
    )
  }
}
