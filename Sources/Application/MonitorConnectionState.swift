enum MonitorConnectionState: Equatable, Sendable {
  case disconnected
  case connecting
  case connected
  case stale
  case reconnecting
  case authenticationFailed
  case unsupported

  var title: String {
    switch self {
    case .disconnected:
      "未连接"
    case .connecting:
      "正在连接"
    case .connected:
      "已连接"
    case .stale:
      "数据已超时"
    case .reconnecting:
      "正在重连"
    case .authenticationFailed:
      "鉴权失败"
    case .unsupported:
      "响应不兼容"
    }
  }

  var symbolName: String {
    switch self {
    case .connected:
      "checkmark.circle.fill"
    case .connecting, .reconnecting:
      "arrow.trianglehead.2.clockwise.rotate.90"
    case .stale:
      "clock.badge.exclamationmark"
    case .authenticationFailed, .unsupported:
      "exclamationmark.triangle.fill"
    case .disconnected:
      "circle.dashed"
    }
  }

  var statusItemTitle: String {
    switch self {
    case .disconnected:
      "未连接"
    case .connecting:
      "连接中"
    case .connected:
      ""
    case .stale:
      "数据超时"
    case .reconnecting:
      "重连中"
    case .authenticationFailed:
      "鉴权失败"
    case .unsupported:
      "不兼容"
    }
  }

  var canPauseForSystemRecovery: Bool {
    switch self {
    case .connecting, .connected, .stale, .reconnecting:
      true
    case .disconnected, .authenticationFailed, .unsupported:
      false
    }
  }
}
