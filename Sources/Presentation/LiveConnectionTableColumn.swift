import AppKit

enum LiveConnectionTableColumn: String, CaseIterable {
  case hostname
  case application
  case download
  case upload
  case cumulative
  case duration

  var title: String {
    switch self {
    case .hostname: "主机名"
    case .application: "应用"
    case .download: "下载"
    case .upload: "上传"
    case .cumulative: "累计"
    case .duration: "时长"
    }
  }

  var minimumWidth: CGFloat {
    switch self {
    case .hostname: 180
    case .application: 140
    case .download, .upload: 90
    case .cumulative: 85
    case .duration: 90
    }
  }

  var width: CGFloat {
    switch self {
    case .hostname: 280
    case .application: 220
    case .download, .upload, .cumulative: 100
    case .duration: 105
    }
  }

  var maximumWidth: CGFloat {
    switch self {
    case .hostname, .application: 500
    case .download, .upload: 110
    case .cumulative: 120
    case .duration: 130
    }
  }

  var isNumeric: Bool {
    self != .hostname && self != .application
  }

  var textColor: NSColor {
    switch self {
    case .download: MihomoColorToken.trafficDownloadNSColor
    case .upload: MihomoColorToken.trafficUploadNSColor
    default: .labelColor
    }
  }

  func text(for connection: LiveTrafficConnection, now: Date) -> String {
    switch self {
    case .hostname:
      return connection.metadata.hostname ?? ConnectionAttributionLabel.unknownHostname
    case .application:
      return connection.metadata.applicationName ?? ConnectionAttributionLabel.unknownApplication
    case .download:
      return TrafficRateFormatter.string(from: connection.rate.downloadBytesPerSecond)
    case .upload:
      return TrafficRateFormatter.string(from: connection.rate.uploadBytesPerSecond)
    case .cumulative:
      return TrafficStatisticsFormatter.bytes(connection.cumulativeBytes.total)
    case .duration:
      guard let startedAt = connection.startedAt else {
        return "—"
      }
      return TrafficStatisticsFormatter.duration(from: startedAt, to: now)
    }
  }
}
