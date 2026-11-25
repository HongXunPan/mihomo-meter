import Foundation
import XCTest

@testable import MihomoMeter

final class LiveConnectionTableRowUpdatePlanTests: XCTestCase {
  func testMovesRowsWhenRatesChangeTheirOrder() throws {
    let plan = try XCTUnwrap(
      LiveConnectionTableRowUpdatePlan(
        previousIDs: ["first", "second", "third"],
        nextIDs: ["third", "first", "second"]
      )
    )
    XCTAssertTrue(plan.removals.isEmpty)
    XCTAssertTrue(plan.insertions.isEmpty)
    XCTAssertEqual(plan.moves.count, 1)
    assertTransforms(plan, from: ["first", "second", "third"], to: ["third", "first", "second"])
  }

  func testCombinesRemovalInsertionAndReordering() throws {
    let old = ["first", "second", "gone", "third"]
    let new = ["third", "added", "second", "first"]
    let plan = try XCTUnwrap(LiveConnectionTableRowUpdatePlan(previousIDs: old, nextIDs: new))
    XCTAssertEqual(plan.removals, IndexSet(integer: 2))
    XCTAssertEqual(plan.insertions, IndexSet(integer: 1))
    assertTransforms(plan, from: old, to: new)
  }

  func testAllInsertionsAndAllRemovals() throws {
    let insert = try XCTUnwrap(
      LiveConnectionTableRowUpdatePlan(previousIDs: [], nextIDs: ["first", "second"])
    )
    assertTransforms(insert, from: [], to: ["first", "second"])

    let remove = try XCTUnwrap(
      LiveConnectionTableRowUpdatePlan(previousIDs: ["first", "second"], nextIDs: [])
    )
    assertTransforms(remove, from: ["first", "second"], to: [])
  }

  func testReplacesRowsWhenSwitchingRoutes() throws {
    let old = ["proxy-first", "proxy-second"]
    let new = ["direct-first", "direct-second"]
    let plan = try XCTUnwrap(LiveConnectionTableRowUpdatePlan(previousIDs: old, nextIDs: new))
    XCTAssertEqual(plan.removals.count, 2)
    XCTAssertEqual(plan.insertions.count, 2)
    XCTAssertTrue(plan.moves.isEmpty)
    assertTransforms(plan, from: old, to: new)
  }

  func testDuplicateIdentifiersUseExistingFullReloadPath() {
    XCTAssertNil(
      LiveConnectionTableRowUpdatePlan(previousIDs: ["same", "same"], nextIDs: ["same"])
    )
    XCTAssertNil(
      LiveConnectionTableRowUpdatePlan(previousIDs: ["same"], nextIDs: ["same", "same"])
    )
  }

  private func assertTransforms(
    _ plan: LiveConnectionTableRowUpdatePlan,
    from old: [String],
    to new: [String]
  ) {
    var current = old
    for index in plan.removals.reversed() {
      current.remove(at: index)
    }
    for index in plan.insertions {
      current.insert(new[index], at: index)
    }
    for move in plan.moves {
      let id = current.remove(at: move.from)
      current.insert(id, at: move.to)
    }
    XCTAssertEqual(current, new)
  }
}
