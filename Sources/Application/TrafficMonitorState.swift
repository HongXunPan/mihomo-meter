import Foundation

struct TrafficMonitorState: Equatable, Sendable {
  var connectionState: MonitorConnectionState = .disconnected
  var rates: CategorizedTrafficRates = .zero
  var rawRates: CategorizedTrafficRates = .zero
  var coverage: Double?
  var activeProxyLeaves: [String] = []
  var mihomoVersion: String?
  var message = "请输入本机 Mihomo 服务地址和访问密钥。"

  mutating func resetLiveData() {
    rates = .zero
    rawRates = .zero
    coverage = nil
    activeProxyLeaves = []
  }
}

struct TrafficStatusItemSnapshot: Equatable, Sendable {
  let rate: TrafficRate
  let connectionState: MonitorConnectionState
}
