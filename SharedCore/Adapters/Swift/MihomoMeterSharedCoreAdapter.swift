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

enum SharedCoreAdapterError: Error, Equatable {
  case nativeCallFailed(Int32)
  case unsupportedABIVersion(UInt32)
  case unsupportedTrafficUnit(UInt32)
}

enum MihomoMeterSharedCoreAdapter {
  private static let expectedABIVersion: UInt32 = 1

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
}
