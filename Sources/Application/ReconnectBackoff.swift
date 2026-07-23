struct ReconnectBackoff: Equatable, Sendable {
  private static let maximumDelay: UInt64 = 30
  private var nextValue: UInt64 = 1

  mutating func nextDelaySeconds() -> UInt64 {
    let current = nextValue
    nextValue = min(nextValue * 2, Self.maximumDelay)
    return current
  }

  mutating func reset() {
    nextValue = 1
  }
}
