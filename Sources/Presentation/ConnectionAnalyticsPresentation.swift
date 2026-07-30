struct ConnectionAnalyticsRankingItem: Equatable, Identifiable {
  let name: String
  let bytes: TrafficBytes

  var id: String {
    name
  }
}

enum ConnectionAnalyticsPresentation {
  static let maximumTopConnectionCount = 5

  static func topConnections(
    from connections: [LiveProxyConnection],
    limit: Int = maximumTopConnectionCount
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

  static func topConnectionSlots(
    from connections: [LiveProxyConnection]
  ) -> [LiveProxyConnection?] {
    let topConnections = topConnections(from: connections)
    return (0..<maximumTopConnectionCount).map { index in
      topConnections.indices.contains(index) ? topConnections[index] : nil
    }
  }

  static func activeConnectionCount(from connections: [LiveProxyConnection]) -> Int {
    connections.count { $0.totalBytesPerSecond > 0 }
  }

  static func activeConnectionSummary(from connections: [LiveProxyConnection]) -> String {
    let count = activeConnectionCount(from: connections)
    return count == 0 ? "暂无传输" : "\(count) 条活跃"
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

  static func applicationTrendTarget(
    applicationName: String,
    selectedHostname: String?
  ) -> ConnectionAnalyticsTrendTarget {
    ConnectionAnalyticsTrendTarget(
      dimension: .application,
      name: applicationName,
      query: ConnectionAnalyticsTrendQuery(
        applicationName: applicationName,
        hostname: selectedHostname
      ),
      inheritedFilterDescription: selectedHostname.map { "域名：\($0)" }
    )
  }

  static func hostnameTrendTarget(
    hostname: String,
    selectedApplication: String?
  ) -> ConnectionAnalyticsTrendTarget {
    ConnectionAnalyticsTrendTarget(
      dimension: .hostname,
      name: hostname,
      query: ConnectionAnalyticsTrendQuery(
        applicationName: selectedApplication,
        hostname: hostname
      ),
      inheritedFilterDescription: selectedApplication.map { "应用：\($0)" }
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
