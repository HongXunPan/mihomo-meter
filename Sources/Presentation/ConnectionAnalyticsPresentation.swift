struct ConnectionAnalyticsRankingItem: Equatable, Identifiable {
  let name: String
  let bytes: TrafficBytes

  var id: String {
    name
  }
}

enum ConnectionAnalyticsPresentation {
  static func topConnections(
    from connections: [LiveProxyConnection],
    limit: Int = 5
  ) -> [LiveProxyConnection] {
    guard limit > 0 else {
      return []
    }

    let activeConnections = connections.filter { $0.totalBytesPerSecond > 0 }
    let sortedConnections = activeConnections.sorted {
      if $0.totalBytesPerSecond != $1.totalBytesPerSecond {
        return $0.totalBytesPerSecond > $1.totalBytesPerSecond
      }
      return ($0.metadata.hostname ?? "") < ($1.metadata.hostname ?? "")
    }
    return Array(sortedConnections.prefix(limit))
  }

  static func applicationNames(
    from records: [ConnectionAttributionRecord]
  ) -> [String] {
    Array(Set(records.map(\.applicationName))).sorted()
  }

  static func hostnames(
    from records: [ConnectionAttributionRecord]
  ) -> [String] {
    Array(Set(records.map(\.hostname))).sorted()
  }

  static func applicationRanking(
    records: [ConnectionAttributionRecord],
    application: String?,
    hostname: String?
  ) -> [ConnectionAnalyticsRankingItem] {
    ranking(
      records: filtered(records, application: application, hostname: hostname),
      name: \.applicationName
    )
  }

  static func hostnameRanking(
    records: [ConnectionAttributionRecord],
    application: String?,
    hostname: String?
  ) -> [ConnectionAnalyticsRankingItem] {
    ranking(
      records: filtered(records, application: application, hostname: hostname),
      name: \.hostname
    )
  }

  private static func filtered(
    _ records: [ConnectionAttributionRecord],
    application: String?,
    hostname: String?
  ) -> [ConnectionAttributionRecord] {
    records.filter { record in
      (application == nil || record.applicationName == application)
        && (hostname == nil || record.hostname == hostname)
    }
  }

  private static func ranking(
    records: [ConnectionAttributionRecord],
    name: KeyPath<ConnectionAttributionRecord, String>
  ) -> [ConnectionAnalyticsRankingItem] {
    var bytesByName: [String: TrafficBytes] = [:]
    for record in records {
      let value = record[keyPath: name]
      bytesByName[value] = (bytesByName[value] ?? .zero) + record.bytes
    }

    let items = bytesByName.map {
      ConnectionAnalyticsRankingItem(name: $0.key, bytes: $0.value)
    }
    return items.sorted {
      if $0.bytes.total != $1.bytes.total {
        return $0.bytes.total > $1.bytes.total
      }
      return $0.name < $1.name
    }
  }
}
