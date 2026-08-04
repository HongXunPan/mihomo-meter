import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class StatusMenuQuotaTrendStateTests: XCTestCase {
  func testKeepsInlineProfileAndRangeSelection() {
    let now = Date(timeIntervalSince1970: 1_700_800_000)
    let firstID = UUID()
    let secondID = UUID()
    let state = StatusMenuQuotaTrendState(now: { now })

    state.prepareForPresentation(
      targetIDs: [firstID, secondID],
      defaultTargetID: firstID
    )
    XCTAssertEqual(state.selectedTargetID, firstID)
    XCTAssertEqual(state.window, .day)
    XCTAssertEqual(state.referenceDate, now)

    state.selectNext(targetIDs: [firstID, secondID])
    state.selectWindow(.week)
    XCTAssertEqual(state.selectedTargetID, secondID)
    XCTAssertEqual(state.window, .week)

    state.prepareForPresentation(
      targetIDs: [firstID, secondID],
      defaultTargetID: firstID
    )
    XCTAssertEqual(state.selectedTargetID, secondID)
    XCTAssertEqual(state.window, .week)

    state.selectPrevious(targetIDs: [firstID, secondID])
    XCTAssertEqual(state.selectedTargetID, firstID)
  }

  func testFollowsChangedCurrentProfileAndRejectsUnsupportedWindow() {
    let firstID = UUID()
    let secondID = UUID()
    let state = StatusMenuQuotaTrendState()

    state.prepareForPresentation(
      targetIDs: [firstID, secondID],
      defaultTargetID: firstID
    )
    state.selectWindow(.month)
    XCTAssertEqual(state.window, .day)

    state.prepareForPresentation(
      targetIDs: [firstID, secondID],
      defaultTargetID: secondID
    )
    XCTAssertEqual(state.selectedTargetID, secondID)
  }

  func testHoverRejectsEventsFromPreviousRangeGeneration() throws {
    let targetID = UUID()
    let oldPointID = UUID()
    let newPointID = UUID()
    let state = StatusMenuQuotaTrendState()

    state.prepareForPresentation(targetIDs: [targetID], defaultTargetID: targetID)
    let dayContext = try XCTUnwrap(state.hoverContext)
    state.hoverState.select(oldPointID, in: dayContext)
    XCTAssertEqual(state.hoverState.selectedPointID, oldPointID)

    state.selectWindow(.week)
    let weekContext = try XCTUnwrap(state.hoverContext)
    XCTAssertNil(state.hoverState.selectedPointID)
    XCTAssertNotEqual(dayContext, weekContext)

    state.hoverState.select(oldPointID, in: dayContext)
    XCTAssertNil(state.hoverState.selectedPointID)

    state.hoverState.select(newPointID, in: weekContext)
    XCTAssertEqual(state.hoverState.selectedPointID, newPointID)
  }

  func testProfileSwitchAndPresentationResetInvalidateHover() throws {
    let firstID = UUID()
    let secondID = UUID()
    let pointID = UUID()
    let state = StatusMenuQuotaTrendState()

    state.prepareForPresentation(
      targetIDs: [firstID, secondID],
      defaultTargetID: firstID
    )
    let firstContext = try XCTUnwrap(state.hoverContext)
    state.hoverState.select(pointID, in: firstContext)

    state.selectNext(targetIDs: [firstID, secondID])
    let secondContext = try XCTUnwrap(state.hoverContext)
    XCTAssertNil(state.hoverState.selectedPointID)
    XCTAssertEqual(secondContext.targetID, secondID)

    state.prepareForPresentation(
      targetIDs: [firstID, secondID],
      defaultTargetID: firstID
    )
    let reopenedContext = try XCTUnwrap(state.hoverContext)
    XCTAssertNil(state.hoverState.selectedPointID)
    XCTAssertNotEqual(secondContext, reopenedContext)
  }
}
