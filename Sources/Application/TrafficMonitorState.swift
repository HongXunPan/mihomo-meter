import Foundation

struct TrafficMonitorState: Equatable, Sendable {
  var connectionState: MonitorConnectionState = .disconnected
  var rates: CategorizedTrafficRates = .zero
  var rawRates: CategorizedTrafficRates = .zero
  var coverage: Double?
  var attributionCoverage = ConnectionAttributionCoverage.empty
  var liveProxyConnections: [LiveTrafficConnection] = []
  var liveDirectConnections: [LiveTrafficConnection] = []
  var activeProxyLeaves: [String] = []
  var activeRuleTypes: [String] = []
  var runtimeConfiguration: MihomoRuntimeConfiguration?
  var mihomoVersion: String?
  var lastObservedAt: Date?
  var message = "首次使用请先准备并连接 Mihomo；不知道它是什么也没关系。"

  mutating func resetLiveData() {
    rates = .zero
    rawRates = .zero
    coverage = nil
    attributionCoverage = .empty
    liveProxyConnections = []
    liveDirectConnections = []
    activeProxyLeaves = []
    activeRuleTypes = []
    lastObservedAt = nil
  }
}

struct TrafficStatusItemSnapshot: Equatable, Sendable {
  let rate: TrafficRate
  let connectionState: MonitorConnectionState
}
