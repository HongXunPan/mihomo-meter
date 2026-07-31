import Foundation

enum MihomoProcessMatchingMode: String, Equatable, Sendable {
  case always
  case strict
  case off

  init?(configurationValue: String?) {
    guard let value = configurationValue?.trimmingCharacters(in: .whitespacesAndNewlines) else {
      return nil
    }
    self.init(rawValue: value.lowercased())
  }
}

struct MihomoRuntimeConfiguration: Equatable, Sendable {
  struct ExternalResourceUserAgent: Equatable, Sendable {
    enum Source: Equatable, Sendable {
      case mihomoConfiguration
      case mihomoDefault
    }

    static let mihomoDefault = ExternalResourceUserAgent(
      value: "clash.meta",
      source: .mihomoDefault
    )

    let value: String
    let source: Source
  }

  let mode: String?
  let tun: MihomoTunRuntimeConfiguration?
  let isIPv6Enabled: Bool?
  let allowsLAN: Bool?
  let mixedPort: Int?
  let httpPort: Int?
  let socksPort: Int?
  let globalUserAgent: String?
  let processMatchingMode: MihomoProcessMatchingMode?

  init(
    mode: String?,
    tun: MihomoTunRuntimeConfiguration?,
    isIPv6Enabled: Bool?,
    allowsLAN: Bool?,
    mixedPort: Int?,
    httpPort: Int? = nil,
    socksPort: Int? = nil,
    globalUserAgent: String? = nil,
    processMatchingMode: MihomoProcessMatchingMode? = nil
  ) {
    self.mode = mode
    self.tun = tun
    self.isIPv6Enabled = isIPv6Enabled
    self.allowsLAN = allowsLAN
    self.mixedPort = mixedPort
    self.httpPort = httpPort
    self.socksPort = socksPort
    self.globalUserAgent = globalUserAgent
    self.processMatchingMode = processMatchingMode
  }

  var externalResourceUserAgent: ExternalResourceUserAgent {
    guard
      let value = globalUserAgent?.trimmingCharacters(in: .whitespacesAndNewlines),
      !value.isEmpty,
      !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    else {
      return .mihomoDefault
    }
    return ExternalResourceUserAgent(value: value, source: .mihomoConfiguration)
  }
}

struct MihomoTunRuntimeConfiguration: Equatable, Sendable {
  let isEnabled: Bool?
  let stack: String?
  let automaticallyRoutesTraffic: Bool?
}
