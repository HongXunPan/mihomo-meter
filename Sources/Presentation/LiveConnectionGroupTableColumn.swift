import AppKit

enum LiveConnectionGroupTableColumn: String, CaseIterable {
  case name
  case relatedCount
  case connectionCount
  case download
  case upload
  case cumulative

  func title(for mode: LiveConnectionViewMode) -> String {
    switch self {
    case .name:
      switch mode {
      case .application: "应用"
      case .hostname: "域名"
      case .connection: "名称"
      }
    case .relatedCount:
      switch mode {
      case .application: "域名数"
      case .hostname: "应用数"
      case .connection: "关联数"
      }
    case .connectionCount: "连接数"
    case .download: "下载"
    case .upload: "上传"
    case .cumulative: "活动累计"
    }
  }

  var minimumWidth: CGFloat {
    switch self {
    case .name: 220
    case .relatedCount, .connectionCount: 72
    case .download, .upload: 90
    case .cumulative: 95
    }
  }

  var width: CGFloat {
    switch self {
    case .name: 360
    case .relatedCount, .connectionCount: 80
    case .download, .upload: 100
    case .cumulative: 110
    }
  }

  var maximumWidth: CGFloat {
    switch self {
    case .name: 500
    case .relatedCount, .connectionCount: 90
    case .download, .upload: 110
    case .cumulative: 130
    }
  }

  var isNumeric: Bool {
    self != .name
  }

  var textColor: NSColor {
    switch self {
    case .download: MihomoColorToken.trafficDownloadNSColor
    case .upload: MihomoColorToken.trafficUploadNSColor
    default: .labelColor
    }
  }

  func text(for row: LiveConnectionGroupRow) -> String {
    switch self {
    case .name: row.name
    case .relatedCount: row.relatedCount.formatted()
    case .connectionCount: row.connectionCount.formatted()
    case .download: TrafficRateFormatter.string(from: row.rate.downloadBytesPerSecond)
    case .upload: TrafficRateFormatter.string(from: row.rate.uploadBytesPerSecond)
    case .cumulative: TrafficStatisticsFormatter.bytes(row.cumulativeBytes.total)
    }
  }
}
