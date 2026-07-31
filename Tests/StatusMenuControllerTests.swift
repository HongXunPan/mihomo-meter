import AppKit
import XCTest

@testable import MihomoMeter

@MainActor
final class StatusMenuControllerTests: XCTestCase {
  func testConfiguredMenuKeepsNativeSubmenusAndNavigationBesideTheirSections() throws {
    var summary = "1 条活跃"
    var quotaSummary = "2 个 Profile"
    var prepareCallCount = 0
    var quotaPrepareCallCount = 0
    let submenuContentSize = NSSize(width: 360, height: 214)
    let quotaTrendContentSize = NSSize(width: 380, height: 460)
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
          submenuConfigurations: [
            StatusMenuSubmenuConfiguration(
              title: "查看订阅走势",
              summary: { quotaSummary },
              contentViewController: makeViewController(),
              contentSize: quotaTrendContentSize,
              prepareForPresentation: { quotaPrepareCallCount += 1 }
            )
          ],
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
    let quotaTrendItem = try XCTUnwrap(
      controller.menu.items.first { $0.title == "查看订阅走势" }
    )
    let quotaTrendIndex = try XCTUnwrap(
      controller.menu.items.firstIndex { $0 === quotaTrendItem }
    )
    XCTAssertTrue(controller.menu.items[trafficIndex - 1].view === trafficController.view)
    XCTAssertEqual(quotaTrendIndex, quotaIndex - 1)
    XCTAssertTrue(controller.menu.items[quotaTrendIndex - 1].view === quotaController.view)
    XCTAssertTrue(controller.menu.items[quotaTrendIndex - 2].isSeparatorItem)
    XCTAssertEqual(quotaTrendItem.badge?.stringValue, "2 个 Profile")
    XCTAssertEqual(quotaPrepareCallCount, 2)
    XCTAssertEqual(quotaTrendItem.submenu?.items.count, 1)
    XCTAssertEqual(
      quotaTrendItem.submenu?.items.first?.view?.frame.size,
      quotaTrendContentSize
    )
    XCTAssertNil(proxyTrafficItem.view)
    XCTAssertNil(subscriptionQuotaItem.view)
    XCTAssertEqual(trafficController.view.frame.height, 420)
    XCTAssertEqual(quotaController.view.frame.height, 360)

    summary = "暂无传输"
    quotaSummary = "暂无数据"
    controller.refreshSummaries()

    XCTAssertEqual(submenuItem.badge?.stringValue, "暂无传输")
    XCTAssertEqual(quotaTrendItem.badge?.stringValue, "暂无数据")
    XCTAssertEqual(quotaPrepareCallCount, 2)

    controller.menuNeedsUpdate(controller.menu)
    XCTAssertEqual(quotaPrepareCallCount, 2)
  }

  func testQuotaTrendStateKeepsInlineProfileAndRangeSelection() {
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

  func testQuotaTrendStateFollowsChangedCurrentProfileAndRejectsUnsupportedWindow() {
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
