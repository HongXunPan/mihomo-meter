import Foundation

struct TrafficScaleFixture: Decodable {
  let schemaVersion: Int
  let byteValues: [String]
}

guard MihomoMeterSharedCoreAdapter.abiVersion == 1 else {
  fatalError("共享核心 ABI 版本不匹配。")
}

guard CommandLine.arguments.count == 2 else {
  fatalError("必须传入统一流量缩放向量文件路径。")
}

let fixtureURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fixture = try JSONDecoder().decode(
  TrafficScaleFixture.self,
  from: Data(contentsOf: fixtureURL)
)
guard fixture.schemaVersion == 1, !fixture.byteValues.isEmpty else {
  fatalError("统一流量缩放向量版本无效或内容为空。")
}

private func formattedNumber(from scale: SharedTrafficScale) -> String {
  let format: String
  switch scale.decimalPlaces {
  case 0:
    format = "%.0f"
  case 1:
    format = "%.1f"
  case 2:
    format = "%.2f"
  default:
    fatalError("共享核心返回了不支持的小数位数：\(scale.decimalPlaces)")
  }
  return String(
    format: format,
    locale: Locale(identifier: "en_US_POSIX"),
    scale.value
  )
}

private func unitText(for unit: SharedTrafficUnit) -> String {
  switch unit {
  case .bytes:
    "B"
  case .kilobytes:
    "KB"
  case .megabytes:
    "MB"
  case .gigabytes:
    "GB"
  case .terabytes:
    "TB"
  }
}

private func compactUnitText(for unit: SharedTrafficUnit) -> String {
  switch unit {
  case .bytes:
    "B"
  case .kilobytes:
    "K"
  case .megabytes:
    "M"
  case .gigabytes:
    "G"
  case .terabytes:
    "T"
  }
}

for rawValue in fixture.byteValues {
  guard let bytes = UInt64(rawValue) else {
    fatalError("统一流量缩放向量包含无效字节值：\(rawValue)")
  }

  let sharedScale = try MihomoMeterSharedCoreAdapter.scaleTraffic(bytes: bytes)
  let sharedNumber = formattedNumber(from: sharedScale)
  let sharedUnit = unitText(for: sharedScale.unit)
  let sharedByteCount = "\(sharedNumber) \(sharedUnit)"
  let sharedRate = "\(sharedNumber) \(sharedUnit)/s"
  let sharedCompactRate = "\(sharedNumber)\(compactUnitText(for: sharedScale.unit))/s"

  guard TrafficStatisticsFormatter.bytes(bytes) == sharedByteCount else {
    fatalError("macOS 累计流量格式化差分不一致：\(rawValue)")
  }
  guard TrafficRateFormatter.string(from: bytes) == sharedRate else {
    fatalError("macOS 完整速率格式化差分不一致：\(rawValue)")
  }
  guard TrafficRateFormatter.compactString(from: bytes) == sharedCompactRate else {
    fatalError("macOS 紧凑速率格式化差分不一致：\(rawValue)")
  }
}

print("macOS Swift 共享核心差分探针通过，共验证 \(fixture.byteValues.count) 个向量。")
