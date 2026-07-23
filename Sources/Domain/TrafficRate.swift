struct TrafficRate: Equatable, Sendable {
  let uploadBytesPerSecond: UInt64
  let downloadBytesPerSecond: UInt64

  static let zero = TrafficRate(
    uploadBytesPerSecond: 0,
    downloadBytesPerSecond: 0
  )
}
