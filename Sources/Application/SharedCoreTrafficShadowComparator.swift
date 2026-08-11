enum SharedCoreTrafficShadowComparator {
  static func compare(
    bytes: UInt64,
    nativeText: String,
    format: SharedCoreTrafficFormat,
    scaleTraffic: (UInt64) throws -> SharedTrafficScale =
      MihomoMeterSharedCoreAdapter.scaleTraffic(bytes:)
  ) -> SharedCoreTrafficShadowStatus {
    SharedCoreTrafficRouter.route(
      bytes: bytes,
      nativeText: nativeText,
      format: format,
      scaleTraffic: scaleTraffic
    ).status
  }
}
