import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class ConnectionLivenessWatchdogTests: XCTestCase {
  func testEmitsStaleBeforeReconnectRequired() async throws {
    let recorder = LivenessEventRecorder()
    let watchdog = ConnectionLivenessWatchdog(
      policy: .init(
        staleAfterNanoseconds: 20_000_000,
        reconnectAfterNanoseconds: 60_000_000,
        backoffResetAfterNanoseconds: 200_000_000
      )
    )

    let streamID = watchdog.beginStream { event in
      await recorder.record(event)
    }

    try await waitUntil {
      await recorder.events.count == 2
    }

    let events = await recorder.events
    guard case .stale(let staleStreamID, let staleAge) = events[0] else {
      return XCTFail("首个事件应为数据超时")
    }
    guard case .reconnectRequired(let reconnectStreamID, let reconnectAge) = events[1]
    else {
      return XCTFail("第二个事件应为重连请求")
    }
    XCTAssertEqual(staleStreamID, streamID)
    XCTAssertEqual(reconnectStreamID, streamID)
    XCTAssertGreaterThanOrEqual(staleAge, 20)
    XCTAssertGreaterThanOrEqual(reconnectAge, 60)
  }

  func testRejectsLateSnapshotAfterForcedTermination() {
    let watchdog = ConnectionLivenessWatchdog(
      policy: .init(
        staleAfterNanoseconds: 100_000_000,
        reconnectAfterNanoseconds: 200_000_000,
        backoffResetAfterNanoseconds: 300_000_000
      )
    )
    let streamID = watchdog.beginStream { _ in }

    XCTAssertTrue(watchdog.acceptSnapshot(streamID: streamID))
    XCTAssertTrue(
      watchdog.requestTermination(
        streamID: streamID,
        reason: .dataStale
      )
    )
    XCTAssertFalse(watchdog.acceptSnapshot(streamID: streamID))

    let completion = watchdog.finishStream()
    XCTAssertEqual(completion.forcedReason, .dataStale)
    XCTAssertFalse(completion.shouldResetBackoff)
  }

  func testStableConnectionRequestsBackoffReset() async throws {
    let watchdog = ConnectionLivenessWatchdog(
      policy: .init(
        staleAfterNanoseconds: 200_000_000,
        reconnectAfterNanoseconds: 400_000_000,
        backoffResetAfterNanoseconds: 20_000_000
      )
    )
    let streamID = watchdog.beginStream { _ in }
    XCTAssertTrue(watchdog.acceptSnapshot(streamID: streamID))

    try await Task.sleep(nanoseconds: 40_000_000)

    let completion = watchdog.finishStream()
    XCTAssertTrue(completion.shouldResetBackoff)
    XCTAssertNil(completion.forcedReason)
  }

  private func waitUntil(
    timeoutNanoseconds: UInt64 = 500_000_000,
    condition: @escaping () async -> Bool
  ) async throws {
    let intervalNanoseconds: UInt64 = 5_000_000
    var waitedNanoseconds: UInt64 = 0

    while !(await condition()), waitedNanoseconds < timeoutNanoseconds {
      try await Task.sleep(nanoseconds: intervalNanoseconds)
      waitedNanoseconds += intervalNanoseconds
    }

    let didFinish = await condition()
    XCTAssertTrue(didFinish, "等待连接存活事件超时")
  }
}

private actor LivenessEventRecorder {
  private(set) var events: [ConnectionLivenessWatchdog.Event] = []

  func record(_ event: ConnectionLivenessWatchdog.Event) {
    events.append(event)
  }
}
