import AppKit
import XCTest

@testable import MihomoMeter

@MainActor
final class ProxyStatusItemViewTests: XCTestCase {
  func testAttachmentUsesAutoresizingWithoutParentConstraints() {
    let button = NSView(frame: NSRect(x: 0, y: 0, width: 66, height: 24))
    let content = ProxyStatusItemView()

    content.attach(to: button)

    XCTAssertTrue(content.superview === button)
    XCTAssertTrue(content.translatesAutoresizingMaskIntoConstraints)
    XCTAssertEqual(content.autoresizingMask, [.width, .minYMargin, .maxYMargin])
    XCTAssertTrue(button.constraints.isEmpty)
    XCTAssertEqual(content.frame, NSRect(x: 4, y: 2, width: 58, height: 20))
    XCTAssertNil(content.hitTest(NSPoint(x: 5, y: 10)))

    button.frame.size = NSSize(width: 80, height: 32)

    XCTAssertEqual(content.frame, NSRect(x: 4, y: 6, width: 72, height: 20))
  }

  func testDirectDrawingUsesOneViewAndRendererSkipsUnchangedContent() {
    let content = ProxyStatusItemView()
    let button = NSView(frame: NSRect(x: 0, y: 0, width: 66, height: 24))
    content.attach(to: button)

    XCTAssertTrue(content.subviews.isEmpty)
    XCTAssertTrue(content.superview === button)
    XCTAssertNil(content.hitTest(NSPoint(x: 5, y: 10)))

    let renderer = ProxyStatusItemDirectRenderer()
    XCTAssertTrue(renderer.update(rate: .zero, state: .disconnected))
    XCTAssertFalse(renderer.update(rate: .zero, state: .disconnected))
    XCTAssertTrue(renderer.update(rate: .zero, state: .connected))
    XCTAssertFalse(renderer.update(rate: .zero, state: .connected))
  }
}
