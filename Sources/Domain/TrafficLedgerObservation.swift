import Foundation

struct TrafficLedgerObservation: Equatable, Sendable {
  let observedAt: Date
  let kernelTotal: TrafficBytes
  let transition: TrafficLedgerTransition
}

enum TrafficLedgerTransition: Equatable, Sendable {
  case baselineEstablished
  case delta(TrafficDeltaReport)
  case countersReset
}
