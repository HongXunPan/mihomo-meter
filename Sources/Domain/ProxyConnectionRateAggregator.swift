struct ProxyConnectionRateAggregator: Sendable {
  private let windowDuration: Double
  private let smoothingWindowCount: Int
  private var accumulatedDuration = 0.0
  private var accumulatedBytesByID: [String: TrafficBytes] = [:]
  private var recentRatesByID: [String: [TrafficRate]] = [:]
  private var rateByID: [String: TrafficRate] = [:]
  private var activeByID: [String: ConnectionTrafficSample] = [:]

  init(windowDuration: Double = 1, smoothingWindowCount: Int = 2) {
    precondition(windowDuration > 0)
    precondition(smoothingWindowCount > 0)
    self.windowDuration = windowDuration
    self.smoothingWindowCount = smoothingWindowCount
  }

  var liveConnections: [LiveProxyConnection] {
    activeByID.values.map { connection in
      LiveProxyConnection(
        id: connection.id,
        metadata: connection.metadata,
        rate: rateByID[connection.id] ?? .zero,
        cumulativeBytes: connection.bytes,
        startedAt: connection.startedAt
      )
    }
  }

  mutating func establishBaseline(_ connections: [ConnectionTrafficSample]) {
    reset()
    activeByID = keyedByID(connections)
  }

  mutating func consume(
    activeConnections: [ConnectionTrafficSample],
    deltas: [ConnectionTrafficDelta],
    elapsedSeconds: Double?
  ) -> [LiveProxyConnection] {
    let activeIDs = Set(activeConnections.map(\.id))
    removeInactiveConnections(except: activeIDs)
    activeByID = keyedByID(activeConnections)

    guard let elapsedSeconds, elapsedSeconds.isFinite, elapsedSeconds > 0 else {
      return liveConnections
    }

    accumulatedDuration += elapsedSeconds
    for delta in deltas where activeIDs.contains(delta.id) {
      accumulatedBytesByID[delta.id] =
        (accumulatedBytesByID[delta.id] ?? .zero) + delta.bytes
    }

    guard accumulatedDuration >= windowDuration else {
      return liveConnections
    }

    for connection in activeConnections {
      let bytes = accumulatedBytesByID[connection.id] ?? .zero
      let rawRate = rate(from: bytes, duration: accumulatedDuration)
      var recentRates = recentRatesByID[connection.id] ?? []
      recentRates.append(rawRate)
      if recentRates.count > smoothingWindowCount {
        recentRates.removeFirst(recentRates.count - smoothingWindowCount)
      }
      recentRatesByID[connection.id] = recentRates
      rateByID[connection.id] = average(recentRates)
    }

    accumulatedDuration = 0
    accumulatedBytesByID = [:]
    return liveConnections
  }

  mutating func reset() {
    accumulatedDuration = 0
    accumulatedBytesByID = [:]
    recentRatesByID = [:]
    rateByID = [:]
    activeByID = [:]
  }

  private mutating func removeInactiveConnections(except activeIDs: Set<String>) {
    accumulatedBytesByID = accumulatedBytesByID.filter { activeIDs.contains($0.key) }
    recentRatesByID = recentRatesByID.filter { activeIDs.contains($0.key) }
    rateByID = rateByID.filter { activeIDs.contains($0.key) }
  }

  private func keyedByID(
    _ connections: [ConnectionTrafficSample]
  ) -> [String: ConnectionTrafficSample] {
    connections.reduce(into: [:]) { result, connection in
      result[connection.id] = connection
    }
  }

  private func rate(from bytes: TrafficBytes, duration: Double) -> TrafficRate {
    TrafficRate(
      uploadBytesPerSecond: bytesPerSecond(bytes.upload, duration: duration),
      downloadBytesPerSecond: bytesPerSecond(bytes.download, duration: duration)
    )
  }

  private func bytesPerSecond(_ bytes: UInt64, duration: Double) -> UInt64 {
    let value = Double(bytes) / duration
    guard value < Double(UInt64.max) else {
      return UInt64.max
    }
    return UInt64(value)
  }

  private func average(_ rates: [TrafficRate]) -> TrafficRate {
    let count = UInt64(rates.count)
    guard count > 0 else {
      return .zero
    }
    let total = rates.reduce(TrafficBytes.zero) { result, rate in
      result
        + TrafficBytes(
          upload: rate.uploadBytesPerSecond,
          download: rate.downloadBytesPerSecond
        )
    }
    return TrafficRate(
      uploadBytesPerSecond: total.upload / count,
      downloadBytesPerSecond: total.download / count
    )
  }
}
