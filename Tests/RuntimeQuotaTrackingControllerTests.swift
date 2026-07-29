import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class RuntimeQuotaTrackingControllerTests: XCTestCase {
  func testRequiresConfirmationBeforeRecordingUniqueRuntimeCandidate() async throws {
    let database = temporaryDatabase()
    defer { removeDatabase(at: database) }
    let ledger = SQLiteQuotaLedger(databaseURL: database)
    let observer = RuntimeQuotaTestObserver()
    let clock = RuntimeQuotaTestClock(date: Date(timeIntervalSince1970: 1_701_000_000))
    let controller = RuntimeQuotaTrackingController(
      ledger: ledger,
      observer: observer,
      now: { clock.date }
    )

    await controller.prepare()
    controller.controllerValidated(endpoint: try endpoint(), secret: "")
    let candidate = try makeCandidate(sourceKey: "provider-a", usedBytes: 200)
    await observer.send(.selection(.single(candidate)))

    XCTAssertNil(controller.snapshot.subscription)
    XCTAssertNil(controller.snapshot.latestQuota)
    XCTAssertEqual(controller.snapshot.observationStatus, .available)

    await controller.enableTracking()

    XCTAssertTrue(controller.snapshot.isActive)
    XCTAssertEqual(controller.snapshot.latestQuota?.traffic.remainingBytes, 800)
    let snapshots = try await ledger.snapshots(
      for: try XCTUnwrap(controller.snapshot.subscription?.id),
      from: clock.date.addingTimeInterval(-1),
      through: clock.date.addingTimeInterval(1)
    )
    XCTAssertEqual(snapshots.count, 1)
  }

  func testDeduplicatesUnchangedCandidateWithoutSourceTime() async throws {
    let context = try await makeEnabledController()
    defer { removeDatabase(at: context.database) }
    context.clock.date = context.clock.date.addingTimeInterval(300)

    await context.observer.send(.selection(.single(context.candidate)))

    let snapshots = try await context.ledger.snapshots(
      for: try XCTUnwrap(context.controller.snapshot.subscription?.id),
      from: context.clock.date.addingTimeInterval(-600),
      through: context.clock.date.addingTimeInterval(1)
    )
    XCTAssertEqual(snapshots.count, 1)
  }

  func testPausesWhenRuntimeSourceChangesAndResumesOnlyAfterConfirmation() async throws {
    let context = try await makeEnabledController()
    defer { removeDatabase(at: context.database) }
    context.clock.date = context.clock.date.addingTimeInterval(300)
    let replacement = try makeCandidate(sourceKey: "provider-b", usedBytes: 300)

    await context.observer.send(.selection(.single(replacement)))

    XCTAssertTrue(context.controller.snapshot.isPaused)
    XCTAssertEqual(context.controller.snapshot.pauseReason, .sourceChanged)
    XCTAssertEqual(context.controller.snapshot.latestQuota?.traffic.usedBytes, 200)

    await context.controller.resumeTracking()

    XCTAssertTrue(context.controller.snapshot.isActive)
    XCTAssertEqual(context.controller.snapshot.latestQuota?.traffic.usedBytes, 300)
  }

  func testPausesWhenCandidateBecomesAmbiguous() async throws {
    let context = try await makeEnabledController()
    defer { removeDatabase(at: context.database) }

    await context.observer.send(.selection(.multiple(count: 2)))

    XCTAssertTrue(context.controller.snapshot.isPaused)
    XCTAssertEqual(context.controller.snapshot.pauseReason, .multipleCandidates)
    XCTAssertEqual(context.controller.snapshot.observationStatus, .multipleCandidates(2))
  }

  func testResetStoredDataKeepsCurrentCandidateAvailableForReenabling() async throws {
    let context = try await makeEnabledController()
    defer { removeDatabase(at: context.database) }

    context.controller.prepareForDataReset()
    try await context.ledger.reset()
    context.controller.completeDataReset()

    XCTAssertNil(context.controller.snapshot.subscription)
    XCTAssertNil(context.controller.snapshot.latestQuota)
    XCTAssertEqual(context.controller.snapshot.observationStatus, .available)

    await context.controller.enableTracking()

    XCTAssertTrue(context.controller.snapshot.isActive)
    XCTAssertEqual(context.controller.snapshot.latestQuota?.traffic.usedBytes, 200)
  }

  private func makeEnabledController() async throws -> RuntimeQuotaTestContext {
    let database = temporaryDatabase()
    let ledger = SQLiteQuotaLedger(databaseURL: database)
    let observer = RuntimeQuotaTestObserver()
    let clock = RuntimeQuotaTestClock(date: Date(timeIntervalSince1970: 1_701_100_000))
    let controller = RuntimeQuotaTrackingController(
      ledger: ledger,
      observer: observer,
      now: { clock.date }
    )
    let candidate = try makeCandidate(sourceKey: "provider-a", usedBytes: 200)

    await controller.prepare()
    controller.controllerValidated(endpoint: try endpoint(), secret: "")
    await observer.send(.selection(.single(candidate)))
    await controller.enableTracking()
    return RuntimeQuotaTestContext(
      database: database,
      ledger: ledger,
      observer: observer,
      clock: clock,
      controller: controller,
      candidate: candidate
    )
  }

  private func makeCandidate(
    sourceKey: String,
    usedBytes: UInt64
  ) throws -> RuntimeQuotaCandidate {
    RuntimeQuotaCandidate(
      sourceKey: sourceKey,
      sourceUpdatedAt: nil,
      traffic: try QuotaTraffic(
        uploadBytes: usedBytes,
        downloadBytes: 0,
        totalBytes: 1_000
      ),
      expireAt: nil
    )
  }

  private func endpoint(port: Int = 9_090) throws -> ControllerEndpoint {
    try ControllerEndpoint(address: "127.0.0.1:\(port)")
  }

  private func temporaryDatabase() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("MihomoMeterRuntimeQuotaTests-\(UUID().uuidString)")
      .appendingPathComponent("quota.sqlite3")
  }

  private func removeDatabase(at url: URL) {
    try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
  }
}

@MainActor
private final class RuntimeQuotaTestObserver: RuntimeQuotaObserving {
  private var handler: RuntimeQuotaObservationHandler?

  func start(
    endpoint: ControllerEndpoint,
    secret: String,
    handler: @escaping RuntimeQuotaObservationHandler
  ) {
    self.handler = handler
  }

  func stop() {
    handler = nil
  }

  func send(_ result: RuntimeQuotaObservationResult) async {
    await handler?(result)
  }
}

@MainActor
private final class RuntimeQuotaTestClock {
  var date: Date

  init(date: Date) {
    self.date = date
  }
}

@MainActor
private struct RuntimeQuotaTestContext {
  let database: URL
  let ledger: SQLiteQuotaLedger
  let observer: RuntimeQuotaTestObserver
  let clock: RuntimeQuotaTestClock
  let controller: RuntimeQuotaTrackingController
  let candidate: RuntimeQuotaCandidate
}
