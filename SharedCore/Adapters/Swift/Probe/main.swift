import Foundation

struct SharedCoreProbeCase {
  let bytes: UInt64
  let expectedValue: Double
  let expectedUnit: SharedTrafficUnit
  let expectedDecimalPlaces: UInt32
}

guard MihomoMeterSharedCoreAdapter.abiVersion == 1 else {
  fatalError("共享核心 ABI 版本不匹配。")
}

let cases = [
  SharedCoreProbeCase(bytes: 0, expectedValue: 0, expectedUnit: .bytes, expectedDecimalPlaces: 0),
  SharedCoreProbeCase(
    bytes: 1_500,
    expectedValue: 1.5,
    expectedUnit: .kilobytes,
    expectedDecimalPlaces: 2
  ),
  SharedCoreProbeCase(
    bytes: 10_000,
    expectedValue: 10,
    expectedUnit: .kilobytes,
    expectedDecimalPlaces: 1
  ),
  SharedCoreProbeCase(
    bytes: 100_000,
    expectedValue: 100,
    expectedUnit: .kilobytes,
    expectedDecimalPlaces: 0
  ),
  SharedCoreProbeCase(
    bytes: 1_000_000_000_000,
    expectedValue: 1,
    expectedUnit: .terabytes,
    expectedDecimalPlaces: 2
  ),
]

for testCase in cases {
  let result = try MihomoMeterSharedCoreAdapter.scaleTraffic(bytes: testCase.bytes)
  guard abs(result.value - testCase.expectedValue) < Double.ulpOfOne,
    result.unit == testCase.expectedUnit,
    result.decimalPlaces == testCase.expectedDecimalPlaces
  else {
    fatalError("共享核心流量缩放结果不一致：\(testCase.bytes)")
  }
}

print("macOS Swift 共享核心探针通过。")
