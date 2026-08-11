import Foundation

struct TrafficScaleFixture: Decodable {
  let schemaVersion: Int
  let byteValues: [String]
}

guard MihomoMeterSharedCoreAdapter.abiVersion == 1 else {
  fatalError("共享核心 ABI 版本不匹配。")
}
guard SharedCoreRuntimeProbe.run() == .ready else {
  fatalError("共享核心生产启动探针未通过。")
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

for rawValue in fixture.byteValues {
  guard let bytes = UInt64(rawValue) else {
    fatalError("统一流量缩放向量包含无效字节值：\(rawValue)")
  }

  let sharedScale = try MihomoMeterSharedCoreAdapter.scaleTraffic(bytes: bytes)
  let sharedByteCount = try SharedCoreTrafficDisplayFormatter.string(
    from: sharedScale,
    format: .byteCount
  )
  let sharedRate = try SharedCoreTrafficDisplayFormatter.string(
    from: sharedScale,
    format: .rate
  )
  let sharedCompactRate = try SharedCoreTrafficDisplayFormatter.string(
    from: sharedScale,
    format: .compactRate
  )

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
