import AppKit
import XCTest

@testable import MihomoMeter

@MainActor
final class StatusMenuControllerTests: XCTestCase {
  func testConfiguredMenuUsesNativeSubmenuAndRefreshesSummary() throws {
    var summary = "1 条活跃"
    var prepareCallCount = 0
    let contentSize = NSSize(width: 360, height: 214)
    let statisticsItem = NSMenuItem(
      title: "查看 Proxy 流量统计",
      action: nil,
      keyEquivalent: ""
    )
    let controller = makeController(
      submenuConfigurations: [
        StatusMenuSubmenuConfiguration(
          title: "活动 Proxy Top 5",
          summary: { summary },
          contentViewController: makeViewController(),
          contentSize: contentSize
        )
      ],
      configuredActionItems: [statisticsItem],
      isConfigurationAvailable: { true },
      prepareForPresentation: { prepareCallCount += 1 }
    )

    controller.menuWillOpen(controller.menu)

    let submenuItem = try XCTUnwrap(
      controller.menu.items.first { $0.title == "活动 Proxy Top 5" }
    )
    XCTAssertEqual(prepareCallCount, 1)
    XCTAssertNotNil(submenuItem.submenu)
    XCTAssertEqual(submenuItem.submenu?.items.first?.view?.frame.size, contentSize)
    XCTAssertEqual(submenuItem.badge?.stringValue, "1 条活跃")
    XCTAssertNil(submenuItem.toolTip)
    XCTAssertFalse(submenuItem.isHidden)
    XCTAssertTrue(controller.menu.items.contains { $0 === statisticsItem })
    XCTAssertNil(statisticsItem.view)
    XCTAssertFalse(statisticsItem.isHidden)

    summary = "暂无传输"
    controller.refreshSummaries()

    XCTAssertEqual(submenuItem.badge?.stringValue, "暂无传输")
  }

  func testUnconfiguredMenuHidesConfiguredSections() throws {
    let statisticsItem = NSMenuItem(
      title: "查看 Proxy 流量统计",
      action: nil,
      keyEquivalent: ""
    )
    let controller = makeController(
      submenuConfigurations: [
        StatusMenuSubmenuConfiguration(
          title: "分类状态",
          summary: { "100.00%" },
          contentViewController: makeViewController(),
          contentSize: NSSize(width: 360, height: 176)
        )
      ],
      configuredActionItems: [statisticsItem],
      isConfigurationAvailable: { false }
    )

    controller.menuWillOpen(controller.menu)

    let submenuItem = try XCTUnwrap(
      controller.menu.items.first { $0.title == "分类状态" }
    )
    XCTAssertTrue(submenuItem.isHidden)
    XCTAssertNil(submenuItem.badge)
    XCTAssertEqual(
      controller.menu.items.first?.view?.frame.size,
      StatusMenuLayout.unconfiguredPrimaryContentSize
    )
    XCTAssertTrue(controller.menu.items[4].isHidden)
    XCTAssertTrue(statisticsItem.isHidden)
  }

  private func makeController(
    submenuConfigurations: [StatusMenuSubmenuConfiguration],
    configuredActionItems: [NSMenuItem] = [],
    isConfigurationAvailable: @escaping () -> Bool,
    prepareForPresentation: @escaping () -> Void = {}
  ) -> StatusMenuController {
    StatusMenuController(
      primaryContentViewController: makeViewController(),
      configuredPrimaryContentSize: StatusMenuLayout.configuredPrimaryContentSize,
      unconfiguredPrimaryContentSize: StatusMenuLayout.unconfiguredPrimaryContentSize,
      summaryContentViewController: makeViewController(),
      summaryContentSize: StatusMenuLayout.summaryContentSize,
      submenuConfigurations: submenuConfigurations,
      configuredActionItems: configuredActionItems,
      isConfigurationAvailable: isConfigurationAvailable,
      prepareForPresentation: prepareForPresentation
    )
  }

  private func makeViewController() -> NSViewController {
    let controller = NSViewController()
    controller.view = NSView(frame: .zero)
    return controller
  }
}
