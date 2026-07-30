import Foundation

enum TrafficMonitorReducer {
  static func reduce(
    _ currentState: TrafficMonitorState,
    event: TrafficMonitoringEvent
  ) -> TrafficMonitorState {
    var state = currentState

    switch event {
    case .validating:
      state.resetLiveData()
      state.mihomoVersion = nil
      state.runtimeConfiguration = nil
      state.connectionState = .connecting
      state.message = "正在验证 Mihomo 服务…"
    case .retrying:
      state.connectionState = .reconnecting
      state.message = "正在重新连接 Mihomo 服务…"
    case .validated(_, let version, let runtimeConfiguration):
      state.mihomoVersion = version
      state.runtimeConfiguration = runtimeConfiguration
      state.resetLiveData()
      state.message = "Mihomo 服务已验证，等待实时数据…"
    case .measurement(let result):
      state.connectionState = .connected
      state.message = "正在读取实时连接流量。"
      state.activeProxyLeaves = result.activeProxyLeaves
      state.activeRuleTypes = result.activeRuleTypes
      state.attributionCoverage = result.attributionCoverage
      state.liveProxyConnections = result.liveProxyConnections
      state.lastObservedAt = result.ledgerObservation.observedAt
      if let window = result.rateWindow {
        state.rawRates = window.raw
        state.rates = window.smoothed
        state.coverage = window.coverage
      }
    case .dataStale(
      let staleTimeoutSeconds,
      let reconnectAfterSeconds,
      _
    ):
      state.connectionState = .stale
      state.message =
        "超过 \(staleTimeoutSeconds) 秒未收到实时数据；持续 \(reconnectAfterSeconds) 秒将重新连接。"
      state.resetLiveData()
    case .reconnectRequired:
      state.runtimeConfiguration = nil
      state.connectionState = .reconnecting
      state.message = "实时数据持续超时，准备重新连接。"
    case .reconnectScheduled(_, let message):
      state.resetLiveData()
      state.runtimeConfiguration = nil
      state.connectionState = .reconnecting
      state.message = message
    case .terminal(let connectionState, let message):
      state.resetLiveData()
      state.runtimeConfiguration = nil
      state.connectionState = connectionState
      state.message = message
    case .stopped:
      state.resetLiveData()
      state.mihomoVersion = nil
      state.runtimeConfiguration = nil
      state.connectionState = .disconnected
      state.message = "监控已停止。"
    }

    return state
  }
}
