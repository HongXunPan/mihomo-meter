import Foundation

enum LiveConnectionViewMode: String, CaseIterable, Identifiable {
  case connection
  case application
  case hostname

  var id: Self {
    self
  }

  var title: String {
    switch self {
    case .connection:
      "连接"
    case .application:
      "应用"
    case .hostname:
      "域名"
    }
  }
}

struct LiveConnectionGroupRow: Equatable, Identifiable {
  let mode: LiveConnectionViewMode
  let name: String
  let relatedCount: Int
  let connectionCount: Int
  let rate: TrafficRate
  let cumulativeBytes: TrafficBytes

  var id: String {
    "\(mode.rawValue):\(name)"
  }

  var totalBytesPerSecond: UInt64 {
    Self.saturatedAdd(rate.uploadBytesPerSecond, rate.downloadBytesPerSecond)
  }

  private static func saturatedAdd(_ left: UInt64, _ right: UInt64) -> UInt64 {
    let (result, overflowed) = left.addingReportingOverflow(right)
    return overflowed ? UInt64.max : result
  }
}

struct ApplicationIdentificationDiagnostic: Equatable {
  let title: String
  let detail: String
  let isWarning: Bool

  init(
    mode: MihomoProcessMatchingMode?,
    coverage: ConnectionAttributionCoverage
  ) {
    let count = "\(coverage.applicationIdentifiedCount)/\(coverage.proxyConnectionCount)"
    switch mode {
    case .always:
      title = "进程识别 always · \(count)"
      detail = "Mihomo 会为所有连接查找进程；系统权限和连接类型仍可能影响结果。"
      isWarning = false
    case .strict:
      title = "进程识别 strict · \(count)"
      detail = "Mihomo 仅在来源可确认时匹配进程，部分连接可能无法识别。"
      isWarning = false
    case .off:
      title = "进程识别 off · \(count)"
      detail = "Mihomo 已关闭进程匹配，应用识别率可能较低。"
      isWarning = true
    case nil:
      title = "进程识别不可确认 · \(count)"
      detail = "Mihomo 未返回可识别的进程匹配模式。"
      isWarning = false
    }
  }
}

enum LiveConnectionAnalyticsPresentation {
  static func connections(
    from connections: [LiveProxyConnection],
    searchText: String
  ) -> [LiveProxyConnection] {
    filtered(connections, searchText: searchText).sorted {
      if $0.totalBytesPerSecond != $1.totalBytesPerSecond {
        return $0.totalBytesPerSecond > $1.totalBytesPerSecond
      }
      let leftHostname = hostname(of: $0)
      let rightHostname = hostname(of: $1)
      if leftHostname != rightHostname {
        return leftHostname < rightHostname
      }
      return $0.id < $1.id
    }
  }

  static func groups(
    from connections: [LiveProxyConnection],
    mode: LiveConnectionViewMode,
    searchText: String
  ) -> [LiveConnectionGroupRow] {
    guard mode != .connection else {
      return []
    }

    var accumulators: [String: GroupAccumulator] = [:]
    for connection in filtered(connections, searchText: searchText) {
      let name = mode == .application ? applicationName(of: connection) : hostname(of: connection)
      let relatedName =
        mode == .application ? hostname(of: connection) : applicationName(of: connection)
      var accumulator = accumulators[name] ?? GroupAccumulator()
      accumulator.relatedNames.insert(relatedName)
      accumulator.connectionCount += 1
      accumulator.rate = adding(accumulator.rate, connection.rate)
      accumulator.cumulativeBytes = accumulator.cumulativeBytes + connection.cumulativeBytes
      accumulators[name] = accumulator
    }

    return accumulators.map { name, accumulator in
      LiveConnectionGroupRow(
        mode: mode,
        name: name,
        relatedCount: accumulator.relatedNames.count,
        connectionCount: accumulator.connectionCount,
        rate: accumulator.rate,
        cumulativeBytes: accumulator.cumulativeBytes
      )
    }
    .sorted {
      if $0.totalBytesPerSecond != $1.totalBytesPerSecond {
        return $0.totalBytesPerSecond > $1.totalBytesPerSecond
      }
      return $0.name < $1.name
    }
  }

  private static func filtered(
    _ connections: [LiveProxyConnection],
    searchText: String
  ) -> [LiveProxyConnection] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      return connections
    }
    return connections.filter {
      applicationName(of: $0).localizedCaseInsensitiveContains(query)
        || hostname(of: $0).localizedCaseInsensitiveContains(query)
    }
  }

  private static func applicationName(of connection: LiveProxyConnection) -> String {
    connection.metadata.applicationName ?? ConnectionAttributionLabel.unknownApplication
  }

  private static func hostname(of connection: LiveProxyConnection) -> String {
    connection.metadata.hostname ?? ConnectionAttributionLabel.unknownHostname
  }

  private static func adding(_ left: TrafficRate, _ right: TrafficRate) -> TrafficRate {
    TrafficRate(
      uploadBytesPerSecond: saturatedAdd(
        left.uploadBytesPerSecond,
        right.uploadBytesPerSecond
      ),
      downloadBytesPerSecond: saturatedAdd(
        left.downloadBytesPerSecond,
        right.downloadBytesPerSecond
      )
    )
  }

  private static func saturatedAdd(_ left: UInt64, _ right: UInt64) -> UInt64 {
    let (result, overflowed) = left.addingReportingOverflow(right)
    return overflowed ? UInt64.max : result
  }
}

private struct GroupAccumulator {
  var relatedNames: Set<String> = []
  var connectionCount = 0
  var rate = TrafficRate.zero
  var cumulativeBytes = TrafficBytes.zero
}
