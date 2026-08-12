import Foundation

struct TrafficScaleFixture: Decodable {
  let schemaVersion: Int
  let byteValues: [String]
}

struct ProxyTypeClassificationFixture: Decodable {
  let schemaVersion: Int
  let cases: [ProxyTypeClassificationCase]
}

struct ProxyTypeClassificationCase: Decodable {
  let rawType: String
  let expected: String
}

guard MihomoMeterSharedCoreAdapter.abiVersion == 1 else {
  fatalError("共享核心 ABI 版本不匹配。")
}
guard SharedCoreRuntimeProbe.run() == .ready else {
  fatalError("共享核心生产启动探针未通过。")
}

guard CommandLine.arguments.count == 3 else {
  fatalError("必须依次传入流量缩放与代理类型分类向量文件路径。")
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

let proxyFixtureURL = URL(fileURLWithPath: CommandLine.arguments[2])
let proxyFixture = try JSONDecoder().decode(
  ProxyTypeClassificationFixture.self,
  from: Data(contentsOf: proxyFixtureURL)
)
guard proxyFixture.schemaVersion == 1, !proxyFixture.cases.isEmpty else {
  fatalError("统一代理类型分类向量版本无效或内容为空。")
}

for testCase in proxyFixture.cases {
  let nativeResult = ProxyClassifier(
    catalog: ProxyCatalog(typesByName: ["Synthetic Proxy": testCase.rawType])
  ).classify(chains: ["Synthetic Proxy"])

  switch testCase.expected {
  case "proxy":
    guard try MihomoMeterSharedCoreAdapter.classifyProxyType(testCase.rawType) == .proxy,
      nativeResult == ProxyClassification(category: .proxy, unknownReason: nil)
    else {
      fatalError("macOS Proxy 分类差分不一致：\(testCase.rawType)")
    }
  case "direct":
    guard try MihomoMeterSharedCoreAdapter.classifyProxyType(testCase.rawType) == .direct,
      nativeResult == ProxyClassification(category: .direct, unknownReason: nil)
    else {
      fatalError("macOS DIRECT 分类差分不一致：\(testCase.rawType)")
    }
  case "reject":
    guard try MihomoMeterSharedCoreAdapter.classifyProxyType(testCase.rawType) == .reject,
      nativeResult == ProxyClassification(category: .reject, unknownReason: nil)
    else {
      fatalError("macOS REJECT 分类差分不一致：\(testCase.rawType)")
    }
  case "unrecognized":
    guard try MihomoMeterSharedCoreAdapter.classifyProxyType(testCase.rawType) == .unrecognized,
      nativeResult
        == ProxyClassification(category: .unknown, unknownReason: .ambiguousProxyType)
    else {
      fatalError("macOS未识别分类差分不一致：\(testCase.rawType)")
    }
  case "unsupported_input":
    guard
      nativeResult
        == ProxyClassification(category: .unknown, unknownReason: .ambiguousProxyType)
    else {
      fatalError("macOS 非 ASCII 原生回退基线不一致：\(testCase.rawType)")
    }
    do {
      _ = try MihomoMeterSharedCoreAdapter.classifyProxyType(testCase.rawType)
      fatalError("macOS 非 ASCII 输入未返回适配器错误：\(testCase.rawType)")
    } catch SharedProxyTypeAdapterError.unsupportedProxyTypeInput {
      break
    }
  case "input_too_long":
    guard
      nativeResult
        == ProxyClassification(category: .unknown, unknownReason: .ambiguousProxyType)
    else {
      fatalError("macOS 超长输入原生回退基线不一致。")
    }
    do {
      _ = try MihomoMeterSharedCoreAdapter.classifyProxyType(testCase.rawType)
      fatalError("macOS 超长输入未返回适配器错误。")
    } catch SharedProxyTypeAdapterError.proxyTypeInputTooLong {
      break
    }
  default:
    fatalError("统一代理类型分类向量包含未知预期：\(testCase.expected)")
  }
}

print(
  "macOS Swift 共享核心差分探针通过，共验证 "
    + "\(fixture.byteValues.count) 个流量向量和 \(proxyFixture.cases.count) 个分类向量。"
)
