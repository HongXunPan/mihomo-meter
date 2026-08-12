import MihomoMeterSharedCore

enum SharedTrafficUnit: UInt32, Equatable {
  case bytes
  case kilobytes
  case megabytes
  case gigabytes
  case terabytes
}

struct SharedTrafficScale: Equatable {
  let value: Double
  let unit: SharedTrafficUnit
  let decimalPlaces: UInt32
}

enum SharedProxyTypeClassification: UInt32, Equatable {
  case unrecognized
  case proxy
  case direct
  case reject
}

enum SharedCoreAdapterError: Error, Equatable {
  case nativeCallFailed(Int32)
  case unsupportedABIVersion(UInt32)
  case unsupportedTrafficUnit(UInt32)
}

enum SharedProxyTypeAdapterError: Error, Equatable {
  case nativeCallFailed(Int32)
  case proxyTypeInputTooLong
  case unsupportedABIVersion(UInt32)
  case unsupportedProxyTypeCategory(UInt32)
  case unsupportedProxyTypeInput
}

enum MihomoMeterSharedCoreAdapter {
  private static let expectedABIVersion: UInt32 = 1
  private static let maximumProxyTypeInputLength = 64
  private static let invalidInputStatus: Int32 = -2
  private static let inputTooLongStatus: Int32 = -3

  static var abiVersion: UInt32 {
    mm_core_abi_version()
  }

  static func scaleTraffic(bytes: UInt64) throws -> SharedTrafficScale {
    guard abiVersion == expectedABIVersion else {
      throw SharedCoreAdapterError.unsupportedABIVersion(abiVersion)
    }
    var result = mm_scaled_traffic_t()
    let status = mm_scale_traffic(bytes, &result)
    guard status == 0 else {
      throw SharedCoreAdapterError.nativeCallFailed(status)
    }
    guard let unit = SharedTrafficUnit(rawValue: result.unit) else {
      throw SharedCoreAdapterError.unsupportedTrafficUnit(result.unit)
    }
    return SharedTrafficScale(
      value: result.value,
      unit: unit,
      decimalPlaces: result.decimal_places
    )
  }

  static func classifyProxyType(_ rawType: String) throws -> SharedProxyTypeClassification {
    guard abiVersion == expectedABIVersion else {
      throw SharedProxyTypeAdapterError.unsupportedABIVersion(abiVersion)
    }

    let input = Array(rawType.utf8)
    guard input.count <= maximumProxyTypeInputLength else {
      throw SharedProxyTypeAdapterError.proxyTypeInputTooLong
    }

    var result = mm_proxy_type_classification_t()
    let status = input.withUnsafeBufferPointer { buffer in
      mm_classify_proxy_type(
        buffer.baseAddress,
        UInt32(buffer.count),
        &result
      )
    }
    switch status {
    case 0:
      break
    case Self.invalidInputStatus:
      throw SharedProxyTypeAdapterError.unsupportedProxyTypeInput
    case Self.inputTooLongStatus:
      throw SharedProxyTypeAdapterError.proxyTypeInputTooLong
    default:
      throw SharedProxyTypeAdapterError.nativeCallFailed(status)
    }

    guard let classification = SharedProxyTypeClassification(rawValue: result.category) else {
      throw SharedProxyTypeAdapterError.unsupportedProxyTypeCategory(result.category)
    }
    return classification
  }
}
