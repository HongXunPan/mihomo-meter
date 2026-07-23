struct ConnectionDeltaTracker: Sendable {
  private var previousKernelTotal: TrafficBytes?
  private var previousConnections: [String: TrafficBytes] = [:]

  mutating func consume(
    _ snapshot: ConnectionTrafficSnapshot,
    classifier: ProxyClassifier
  ) -> ConnectionDeltaResult {
    guard let previousKernelTotal else {
      establishBaseline(from: snapshot)
      return .baselineEstablished
    }

    guard
      let kernelDelta = TrafficBytes.nonnegativeDelta(
        current: snapshot.kernelTotal,
        previous: previousKernelTotal
      )
    else {
      establishBaseline(from: snapshot)
      return .countersReset
    }

    var categories = CategorizedTrafficBytes.zero

    for connection in snapshot.connections {
      let delta: TrafficBytes
      if let previous = previousConnections[connection.id] {
        guard
          let existingDelta = TrafficBytes.nonnegativeDelta(
            current: connection.bytes,
            previous: previous
          )
        else {
          continue
        }
        delta = existingDelta
      } else {
        delta = connection.bytes
      }

      let classification = classifier.classify(chains: connection.chains)
      guard classification.category != .unknown else {
        continue
      }

      categories = categories.adding(delta, to: classification.category)
    }

    let unknown = TrafficBytes.residual(
      total: kernelDelta,
      subtracting: categories.classified
    )
    categories = categories.adding(unknown, to: .unknown)
    establishBaseline(from: snapshot)

    return .delta(TrafficDeltaReport(kernel: kernelDelta, categories: categories))
  }

  mutating func reset() {
    previousKernelTotal = nil
    previousConnections = [:]
  }

  private mutating func establishBaseline(from snapshot: ConnectionTrafficSnapshot) {
    previousKernelTotal = snapshot.kernelTotal
    previousConnections = snapshot.connections.reduce(into: [:]) {
      $0[$1.id] = $1.bytes
    }
  }
}

enum ConnectionDeltaResult: Equatable, Sendable {
  case baselineEstablished
  case delta(TrafficDeltaReport)
  case countersReset
}
