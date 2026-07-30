import AppKit
import XCTest

@testable import MihomoMeter

@MainActor
final class StatusMenuControllerTests: XCTestCase {
  func testConfiguredMenuKeepsNativeSubmenusAndNavigationBesideTheirSections() throws {
    var summary = "1 条活跃"
    var prepareCallCount = 0
    let submenuContentSize = NSSize(width: 360, height: 214)
    let trafficController = makeViewController()
    let quotaController = makeViewController()
    let proxyTrafficItem = NSMenuItem(title: "查看 Proxy 流量统计", action: nil, keyEquivalent: "")
    let subscriptionQuotaItem = NSMenuItem(
      title: "查看订阅余额统计",
      action: nil,
      keyEquivalent: ""
    )
    let controller = StatusMenuController(
      primaryContent: contentConfiguration(height: 166),
      submenuConfigurations: [
        StatusMenuSubmenuConfiguration(
          title: "活动 Proxy Top 5",
          summary: { summary },
          contentViewController: makeViewController(),
          contentSize: submenuContentSize
        )
      ],
      sectionConfigurations: [
        StatusMenuSectionConfiguration(
          content: contentConfiguration(
            viewController: trafficController,
            height: 420
          ),
          navigationItem: proxyTrafficItem
        ),
        StatusMenuSectionConfiguration(
          content: contentConfiguration(
            viewController: quotaController,
            height: 360
          ),
          navigationItem: subscriptionQuotaItem
        ),
      ],
      isConfigurationAvailable: { true },
      prepareForPresentation: { prepareCallCount += 1 }
    )

    controller.menuWillOpen(controller.menu)

    let submenuItem = try XCTUnwrap(
      controller.menu.items.first { $0.title == "活动 Proxy Top 5" }
    )
    XCTAssertEqual(prepareCallCount, 1)
    XCTAssertNotNil(submenuItem.submenu)
    XCTAssertEqual(submenuItem.submenu?.items.first?.view?.frame.size, submenuContentSize)
    XCTAssertEqual(submenuItem.badge?.stringValue, "1 条活跃")
    XCTAssertNil(submenuItem.toolTip)
    XCTAssertNil(submenuItem.view)
    XCTAssertFalse(submenuItem.isHidden)

    let trafficIndex = try XCTUnwrap(controller.menu.items.firstIndex { $0 === proxyTrafficItem })
    let quotaIndex = try XCTUnwrap(
      controller.menu.items.firstIndex { $0 === subscriptionQuotaItem }
    )
    XCTAssertTrue(controller.menu.items[trafficIndex - 1].view === trafficController.view)
    XCTAssertTrue(controller.menu.items[quotaIndex - 1].view === quotaController.view)
    XCTAssertTrue(controller.menu.items[quotaIndex - 2].isSeparatorItem)
    XCTAssertNil(proxyTrafficItem.view)
    XCTAssertNil(subscriptionQuotaItem.view)
    XCTAssertEqual(trafficController.view.frame.height, 420)
    XCTAssertEqual(quotaController.view.frame.height, 360)

    summary = "暂无传输"
    controller.refreshSummaries()

    XCTAssertEqual(submenuItem.badge?.stringValue, "暂无传输")
  }

  func testMenuRefreshesNaturalContentSizesWithoutApplyingViewportCap() {
    var primaryHeight: CGFloat = 166
    var sectionHeight: CGFloat = 720
    let sectionController = makeViewController()
    let controller = StatusMenuController(
      primaryContent: contentConfiguration(height: { primaryHeight }),
      submenuConfigurations: [],
      sectionConfigurations: [
        StatusMenuSectionConfiguration(
          content: contentConfiguration(
            viewController: sectionController,
            height: { sectionHeight }
          ),
          navigationItem: NSMenuItem(title: "查看统计", action: nil, keyEquivalent: "")
        )
      ],
      isConfigurationAvailable: { true }
    )

    primaryHeight = 220
    sectionHeight = 840
    controller.refreshContentSizes()

    XCTAssertEqual(controller.menu.items[0].view?.frame.height, 220)
    XCTAssertEqual(sectionController.view.frame.height, 840)
  }

  func testUnconfiguredMenuHidesAllConfiguredItems() {
    let controller = StatusMenuController(
      primaryContent: contentConfiguration(height: 420),
      submenuConfigurations: [
        StatusMenuSubmenuConfiguration(
          title: "分类状态",
          summary: { "100.00%" },
          contentViewController: makeViewController(),
          contentSize: NSSize(width: 360, height: 176)
        )
      ],
      sectionConfigurations: [
        StatusMenuSectionConfiguration(
          content: contentConfiguration(height: 300),
          navigationItem: NSMenuItem(title: "查看统计", action: nil, keyEquivalent: "")
        )
      ],
      isConfigurationAvailable: { false }
    )

    controller.menuWillOpen(controller.menu)

    XCTAssertFalse(controller.menu.items[0].isHidden)
    XCTAssertEqual(controller.menu.items[0].view?.frame.height, 420)
    XCTAssertTrue(controller.menu.items.dropFirst().allSatisfy(\.isHidden))
    XCTAssertNil(controller.menu.items.first { $0.title == "分类状态" }?.badge)
  }

  private func contentConfiguration(
    viewController: NSViewController? = nil,
    height: @escaping () -> CGFloat
  ) -> StatusMenuContentConfiguration {
    StatusMenuContentConfiguration(
      viewController: viewController ?? makeViewController(),
      contentSize: {
        NSSize(width: StatusMenuLayout.contentWidth, height: height())
      }
    )
  }

  private func contentConfiguration(
    viewController: NSViewController? = nil,
    height: CGFloat
  ) -> StatusMenuContentConfiguration {
    contentConfiguration(viewController: viewController, height: { height })
  }

  private func makeViewController() -> NSViewController {
    let controller = NSViewController()
    controller.view = NSView(frame: .zero)
    return controller
  }
}
