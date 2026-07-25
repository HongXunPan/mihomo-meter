import Foundation

struct TrafficMeasurementResult: Equatable, Sendable {
  let activeProxyLeaves: [String]
  let activeRuleTypes: [String]
  let requiresCatalogRefresh: Bool
  let ledgerObservation: TrafficLedgerObservation
  let rateWindow: TrafficRateWindow?
}

struct TrafficMeasurementSession: Sendable {
  private var classifier: ProxyClassifier?
  private var deltaTracker = ConnectionDeltaTracker()
  private var rateAggregator = TrafficRateAggregator()
  private var lastSnapshotInstant: ContinuousClock.Instant?

  mutating func configure(catalog: ProxyCatalog) {
    classifier = ProxyClassifier(catalog: catalog)
    resetBaseline()
  }

  mutating func updateCatalog(_ catalog: ProxyCatalog) {
    classifier = ProxyClassifier(catalog: catalog)
  }

  mutating func consume(
    _ snapshot: ConnectionTrafficSnapshot,
    at instant: ContinuousClock.Instant = ContinuousClock().now,
    observedAt: Date = Date()
  ) -> TrafficMeasurementResult? {
    guard let classifier else {
      return nil
    }

    let classifications = snapshot.connections.map { connection in
      (
        connection: connection,
        classification: classifier.classify(chains: connection.chains)
      )
    }
    let proxyLeaves: [String] = classifications.compactMap { item in
      guard item.classification.category == .proxy else {
        return nil
      }
      return item.connection.chains.first
    }
    let activeProxyLeaves = Array(Set(proxyLeaves)).sorted()
    let activeRuleTypes = Array(
      Set(
        snapshot.connections.compactMap { connection in
          let rule = connection.rule?.trimmingCharacters(in: .whitespacesAndNewlines)
          return rule.flatMap { $0.isEmpty ? nil : $0 }
        }
      )
    ).sorted()
    let requiresCatalogRefresh = classifications.contains {
      $0.classification.unknownReason == .missingCatalogEntry
    }

    let elapsedSeconds = lastSnapshotInstant.map {
      Self.seconds(from: $0.duration(to: instant))
    }
    lastSnapshotInstant = instant

    let transition: TrafficLedgerTransition
    let rateWindow: TrafficRateWindow?
    switch deltaTracker.consume(snapshot, classifier: classifier) {
    case .baselineEstablished:
      transition = .baselineEstablished
      rateWindow = nil
    case .delta(let report):
      transition = .delta(report)
      rateWindow = elapsedSeconds.flatMap {
        rateAggregator.consume(report, elapsedSeconds: $0)
      }
    case .countersReset:
      transition = .countersReset
      rateWindow = nil
    }

    return TrafficMeasurementResult(
      activeProxyLeaves: activeProxyLeaves,
      activeRuleTypes: activeRuleTypes,
      requiresCatalogRefresh: requiresCatalogRefresh,
      ledgerObservation: TrafficLedgerObservation(
        observedAt: observedAt,
        kernelTotal: snapshot.kernelTotal,
        transition: transition
      ),
      rateWindow: rateWindow
    )
  }

  mutating func resetBaseline() {
    deltaTracker.reset()
    rateAggregator.reset()
    lastSnapshotInstant = nil
  }

  private static func seconds(from duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds)
      + Double(components.attoseconds) / 1_000_000_000_000_000_000
  }
}
