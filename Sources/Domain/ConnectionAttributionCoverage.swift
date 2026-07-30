struct ConnectionMetadataAvailability: Equatable, Sendable {
  let hasHostname: Bool
  let hasApplication: Bool

  static let unavailable = ConnectionMetadataAvailability(
    hasHostname: false,
    hasApplication: false
  )
}

struct ConnectionMetadata: Equatable, Sendable {
  let hostname: String?
  let applicationName: String?

  static let unavailable = ConnectionMetadata(hostname: nil, applicationName: nil)

  var availability: ConnectionMetadataAvailability {
    ConnectionMetadataAvailability(
      hasHostname: hostname != nil,
      hasApplication: applicationName != nil
    )
  }
}

struct ConnectionAttributionCoverage: Equatable, Sendable {
  let proxyConnectionCount: Int
  let hostnameIdentifiedCount: Int
  let applicationIdentifiedCount: Int
  let fullyIdentifiedCount: Int

  static let empty = ConnectionAttributionCoverage(
    proxyConnectionCount: 0,
    hostnameIdentifiedCount: 0,
    applicationIdentifiedCount: 0,
    fullyIdentifiedCount: 0
  )

  var hostnameRate: Double? {
    rate(for: hostnameIdentifiedCount)
  }

  var applicationRate: Double? {
    rate(for: applicationIdentifiedCount)
  }

  var fullyIdentifiedRate: Double? {
    rate(for: fullyIdentifiedCount)
  }

  private func rate(for count: Int) -> Double? {
    guard proxyConnectionCount > 0 else {
      return nil
    }
    return Double(count) / Double(proxyConnectionCount)
  }
}

struct ConnectionAttributionCoverageTracker: Sendable {
  private var availabilityByConnectionID: [String: ConnectionMetadataAvailability] = [:]

  mutating func consume(
    _ connections: [ConnectionTrafficSample]
  ) -> ConnectionAttributionCoverage {
    for connection in connections {
      let previous = availabilityByConnectionID[connection.id] ?? .unavailable
      availabilityByConnectionID[connection.id] = ConnectionMetadataAvailability(
        hasHostname: previous.hasHostname || connection.metadataAvailability.hasHostname,
        hasApplication: previous.hasApplication || connection.metadataAvailability.hasApplication
      )
    }
    return coverage
  }

  mutating func reset() {
    availabilityByConnectionID = [:]
  }

  private var coverage: ConnectionAttributionCoverage {
    let values = Array(availabilityByConnectionID.values)
    return ConnectionAttributionCoverage(
      proxyConnectionCount: values.count,
      hostnameIdentifiedCount: values.filter(\.hasHostname).count,
      applicationIdentifiedCount: values.filter(\.hasApplication).count,
      fullyIdentifiedCount: values.count { $0.hasHostname && $0.hasApplication }
    )
  }
}
