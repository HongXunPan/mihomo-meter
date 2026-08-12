struct ProxyCatalog: Equatable, Sendable {
  private let typesByName: [String: String]

  init(typesByName: [String: String]) {
    self.typesByName = typesByName
  }

  func type(for name: String) -> String? {
    typesByName[name]
  }
}

struct ProxyClassification: Equatable, Sendable {
  let category: TrafficCategory
  let unknownReason: UnknownTrafficReason?
}

typealias ProxyTypeResolver =
  @Sendable (
    _ rawType: String,
    _ nativeClassification: ProxyClassification
  ) -> ProxyClassification

enum UnknownTrafficReason: String, Equatable, Sendable {
  case emptyChain
  case missingCatalogEntry
  case ambiguousProxyType
}

struct ProxyClassifier: Sendable {
  private static let concreteProxyTypes: Set<String> = [
    "anytls",
    "http",
    "hysteria",
    "hysteria2",
    "shadowsocks",
    "shadowsocksr",
    "snell",
    "socks5",
    "ssh",
    "trojan",
    "tuic",
    "vless",
    "vmess",
    "wireguard",
  ]

  private let catalog: ProxyCatalog
  private let resolveProxyType: ProxyTypeResolver

  init(
    catalog: ProxyCatalog,
    resolveProxyType: @escaping ProxyTypeResolver = { _, nativeClassification in
      nativeClassification
    }
  ) {
    self.catalog = catalog
    self.resolveProxyType = resolveProxyType
  }

  func classify(chains: [String]) -> ProxyClassification {
    guard let leaf = chains.first, !leaf.isEmpty else {
      return ProxyClassification(category: .unknown, unknownReason: .emptyChain)
    }

    guard let rawType = catalog.type(for: leaf) else {
      return ProxyClassification(category: .unknown, unknownReason: .missingCatalogEntry)
    }

    let nativeClassification = Self.classifyNatively(rawType: rawType)
    return resolveProxyType(rawType, nativeClassification)
  }

  private static func classifyNatively(rawType: String) -> ProxyClassification {
    let normalizedType =
      rawType
      .lowercased()
      .filter { $0.isLetter || $0.isNumber }

    switch normalizedType {
    case "direct":
      return ProxyClassification(category: .direct, unknownReason: nil)
    case "reject", "rejectdrop":
      return ProxyClassification(category: .reject, unknownReason: nil)
    case let value where Self.concreteProxyTypes.contains(value):
      return ProxyClassification(category: .proxy, unknownReason: nil)
    default:
      return ProxyClassification(category: .unknown, unknownReason: .ambiguousProxyType)
    }
  }
}
