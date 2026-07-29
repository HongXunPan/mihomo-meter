import Foundation

enum QuotaLedgerError: Error, Equatable, LocalizedError {
  case invalidSubscriptionName
  case invalidProfileUID
  case invalidRefreshInterval
  case invalidTotal
  case byteCountOverflow
  case subscriptionNotFound
  case identityChangeRequiresMigration
  case sourceMismatch
  case nonMonotonicObservation
  case invalidTimeRange
  case invalidStoredData
  case unsupportedSchema(Int)

  var errorDescription: String? {
    switch self {
    case .invalidSubscriptionName:
      "订阅名称不能为空。"
    case .invalidProfileUID:
      "Profile UID 无效。"
    case .invalidRefreshInterval:
      "订阅查询间隔无效。"
    case .invalidTotal:
      "机场没有提供有效的套餐总量。"
    case .byteCountOverflow:
      "机场配额超出本地数据库支持范围。"
    case .subscriptionNotFound:
      "找不到需要记录的订阅。"
    case .identityChangeRequiresMigration:
      "订阅身份变化需要先确认历史迁移。"
    case .sourceMismatch:
      "配额来源与订阅追踪模式不一致。"
    case .nonMonotonicObservation:
      "配额观测时间早于或等于最近快照。"
    case .invalidTimeRange:
      "配额查询时间范围无效。"
    case .invalidStoredData:
      "本地配额数据无效。"
    case .unsupportedSchema:
      "本地配额数据库版本暂不受支持。"
    }
  }
}
