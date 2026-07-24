struct MihomoRuntimeConfiguration: Equatable, Sendable {
  let mode: String?
  let tun: MihomoTunRuntimeConfiguration?
  let isIPv6Enabled: Bool?
  let allowsLAN: Bool?
  let mixedPort: Int?
}

struct MihomoTunRuntimeConfiguration: Equatable, Sendable {
  let isEnabled: Bool?
  let stack: String?
  let automaticallyRoutesTraffic: Bool?
}
