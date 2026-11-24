import AppKit
import XCTest

@testable import MihomoMeter

@MainActor
final class WindowContentMountTests: XCTestCase {
  func testClosedWindowReleasesContentAndReopenCreatesItAgain() {
    let window = NSWindow(
      contentRect: NSRect(x: 40, y: 50, width: 900, height: 560),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    let originalFrame = window.frame
    var creationCount = 0
    let mount = WindowContentMount {
      creationCount += 1
      let controller = NSViewController()
      controller.view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 560))
      return controller
    }

    XCTAssertNil(window.contentViewController)
    XCTAssertEqual(creationCount, 0)

    mount.attach(to: window)
    var firstContent = window.contentViewController
    weak var releasedContent = firstContent
    mount.attach(to: window)
    XCTAssertTrue(window.contentViewController === firstContent)
    XCTAssertEqual(creationCount, 1)
    XCTAssertEqual(window.frame, originalFrame)

    firstContent = nil
    mount.detach(from: window)
    XCTAssertNil(window.contentViewController)
    XCTAssertNil(releasedContent)

    mount.attach(to: window)
    XCTAssertNotNil(window.contentViewController)
    XCTAssertEqual(creationCount, 2)
    XCTAssertEqual(window.frame, originalFrame)
  }
}
