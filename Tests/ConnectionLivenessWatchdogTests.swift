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

  func testCancelledStaleTimerDoesNotEmitAfterFreshSnapshot() async throws {
    let sleeper = ManualLivenessSleeper()
    let recorder = LivenessEventRecorder()
    let watchdog = ConnectionLivenessWatchdog(
      policy: .init(
        staleAfterNanoseconds: 20_000_000,
        reconnectAfterNanoseconds: 60_000_000,
        backoffResetAfterNanoseconds: 200_000_000
      ),
      sleep: { _ in await sleeper.sleep() }
    )
    let streamID = watchdog.beginStream { event in
      await recorder.record(event)
    }

    try await waitUntil { await sleeper.pendingCount == 1 }
    XCTAssertTrue(watchdog.acceptSnapshot(streamID: streamID))
    try await waitUntil { await sleeper.pendingCount == 2 }
    await sleeper.resumeFirst()
    try await Task.sleep(nanoseconds: 30_000_000)

    let events = await recorder.events
    XCTAssertTrue(events.isEmpty)
    watchdog.cancel()
    await sleeper.resumeAll()
  }

  func testCancelledReconnectTimerDoesNotEmitAfterFreshSnapshot() async throws {
    let sleeper = ManualLivenessSleeper()
    let recorder = LivenessEventRecorder()
    let watchdog = ConnectionLivenessWatchdog(
      policy: .init(
        staleAfterNanoseconds: 20_000_000,
        reconnectAfterNanoseconds: 60_000_000,
        backoffResetAfterNanoseconds: 200_000_000
      ),
      sleep: { _ in await sleeper.sleep() }
    )
    let streamID = watchdog.beginStream { event in
      await recorder.record(event)
    }

    try await waitUntil { await sleeper.pendingCount == 1 }
    try await Task.sleep(nanoseconds: 30_000_000)
    await sleeper.resumeFirst()
    try await waitUntil { await recorder.events.count == 1 }
    try await waitUntil { await sleeper.pendingCount == 1 }

    XCTAssertTrue(watchdog.acceptSnapshot(streamID: streamID))
    try await waitUntil { await sleeper.pendingCount == 2 }
    await sleeper.resumeFirst()
    try await Task.sleep(nanoseconds: 30_000_000)

    let events = await recorder.events
    XCTAssertEqual(events.count, 1)
    watchdog.cancel()
    await sleeper.resumeAll()
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

private actor ManualLivenessSleeper {
  private var continuations: [CheckedContinuation<Void, Never>] = []

  var pendingCount: Int {
    continuations.count
  }

  func sleep() async {
    await withCheckedContinuation { continuation in
      continuations.append(continuation)
    }
  }

  func resumeFirst() {
    guard !continuations.isEmpty else {
      return
    }
    continuations.removeFirst().resume()
  }

  func resumeAll() {
    for continuation in continuations {
      continuation.resume()
    }
    continuations.removeAll()
  }
}
