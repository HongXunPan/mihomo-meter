import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class ProfileDirectoryObserverTests: XCTestCase {
  func testDebouncesAtomicDirectoryChanges() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("MihomoMeterProfileObserverTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }

    let observer = ProfileDirectoryObserver()
    let changed = expectation(description: "目录变化已合并")
    changed.expectedFulfillmentCount = 1
    changed.assertForOverFulfill = true
    try observer.startObserving(directoryURL: directory) {
      changed.fulfill()
    }

    let file = directory.appendingPathComponent("profiles.yaml")
    try "current: a".write(to: file, atomically: true, encoding: .utf8)
    try "current: b".write(to: file, atomically: true, encoding: .utf8)

    await fulfillment(of: [changed], timeout: 2)
    try await Task.sleep(for: .milliseconds(600))
    observer.stopObserving()
  }
}
