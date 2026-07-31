import AppKit
import SwiftUI

@MainActor
struct StatusMenuFactory {
  let monitor: TrafficMonitor
  let statisticsController: TrafficStatisticsController
  let quotaController: RuntimeQuotaTrackingController
  let profileQuotaController: ProfileQuotaTrackingController

  func makeController(
    showControllerSettings: @escaping () -> Void,
    showTrafficStatistics: @escaping () -> Void,
    proxyTrafficNavigationItem: NSMenuItem,
    subscriptionQuotaNavigationItem: NSMenuItem
  ) -> StatusMenuController {
    let primaryContent = makeMenuContentConfiguration(
      rootView: StatusMenuPrimaryContentView(
        monitor: monitor,
        showControllerSettings: showControllerSettings
      )
    )
    let trafficSummaryContent = makeMenuContentConfiguration(
      rootView: StatusMenuTrafficSummaryContentView(
        monitor: monitor,
        controller: statisticsController
      )
    )
    let quotaSummaryContent = makeMenuContentConfiguration(
      rootView: StatusMenuQuotaSummaryContentView(
        controller: quotaController,
        profileQuotaController: profileQuotaController
      )
    )
    let quotaTrendCoordinator = StatusMenuQuotaTrendMenuCoordinator(
      controller: quotaController,
      profileQuotaController: profileQuotaController
    )
    let trafficTasksCoordinator = StatusMenuTrafficTasksMenuCoordinator(
      controller: statisticsController,
      isMonitoringAvailable: trafficStatisticsMonitoringAvailable,
      showStatistics: showTrafficStatistics
    )

    return StatusMenuController(
      primaryContent: primaryContent,
      submenuConfigurations: makeSubmenuConfigurations(),
      sectionConfigurations: [
        StatusMenuSectionConfiguration(
          content: trafficSummaryContent,
          submenuConfigurations: [
            StatusMenuSubmenuConfiguration(
              title: "统计任务",
              badge: trafficTaskBadge,
              accessibilitySummary: trafficTaskSummary,
              contentViewController: trafficTasksCoordinator.contentViewController,
              contentSize: StatusMenuLayout.trafficTasksSubmenuSize
            )
          ],
          navigationItem: proxyTrafficNavigationItem
        ),
        StatusMenuSectionConfiguration(
          content: quotaSummaryContent,
          submenuConfigurations: [
            StatusMenuSubmenuConfiguration(
              title: "查看订阅走势",
              summary: quotaTrendSummary,
              contentViewController: quotaTrendCoordinator.contentViewController,
              contentSize: StatusMenuLayout.quotaTrendSubmenuSize,
              prepareForPresentation: quotaTrendCoordinator.prepareForPresentation
            )
          ],
          navigationItem: subscriptionQuotaNavigationItem
        ),
      ],
      isConfigurationAvailable: {
        monitor.hasValidatedControllerConfiguration
      }
    )
  }

  private func makeSubmenuConfigurations() -> [StatusMenuSubmenuConfiguration] {
    let proxyConnectionsController = makeFixedHostingController(
      rootView: ProxyConnectionTopListView(monitor: monitor),
      contentSize: StatusMenuLayout.connectionSubmenuSize
    )
    let directConnectionsController = makeFixedHostingController(
      rootView: DirectConnectionTopListView(monitor: monitor),
      contentSize: StatusMenuLayout.connectionSubmenuSize
    )
    let classificationController = makeFixedHostingController(
      rootView: TrafficClassificationView(monitor: monitor),
      contentSize: StatusMenuLayout.classificationSubmenuSize
    )
    let routingController = makeFixedHostingController(
      rootView: RoutingStatusView(monitor: monitor),
      contentSize: StatusMenuLayout.routingSubmenuSize
    )

    return [
      StatusMenuSubmenuConfiguration(
        title: "活动 Proxy Top 5",
        summary: {
          ConnectionAnalyticsPresentation.activeConnectionSummary(
            from: monitor.liveProxyConnections
          )
        },
        contentViewController: proxyConnectionsController,
        contentSize: StatusMenuLayout.connectionSubmenuSize
      ),
      StatusMenuSubmenuConfiguration(
        title: "活动直连 Top 5",
        summary: {
          ConnectionAnalyticsPresentation.activeConnectionSummary(
            from: monitor.liveDirectConnections
          )
        },
        contentViewController: directConnectionsController,
        contentSize: StatusMenuLayout.connectionSubmenuSize
      ),
      StatusMenuSubmenuConfiguration(
        title: "分类状态",
        summary: {
          TrafficRateFormatter.percentage(from: monitor.coverage)
        },
        contentViewController: classificationController,
        contentSize: StatusMenuLayout.classificationSubmenuSize
      ),
      StatusMenuSubmenuConfiguration(
        title: "路由状态",
        summary: {
          routingStatusPresentation.statusSummary
        },
        contentViewController: routingController,
        contentSize: StatusMenuLayout.routingSubmenuSize
      ),
    ]
  }

  private func makeMenuContentConfiguration<Content: View>(
    rootView: Content
  ) -> StatusMenuContentConfiguration {
    let contentWidth = StatusMenuLayout.contentWidth
    let controller = StatusMenuNaturalHeightHostingController(rootView: rootView)
    controller.sizingOptions = [.preferredContentSize, .intrinsicContentSize]
    controller.view.setContentHuggingPriority(.required, for: .vertical)
    controller.view.setContentCompressionResistancePriority(.required, for: .vertical)
    controller.contentSizeDidChange = { [weak controller] contentSize in
      Task { @MainActor [weak controller] in
        await Task.yield()
        guard let controller, contentSize.height > 0 else {
          return
        }
        let measuredSize = NSSize(
          width: contentWidth,
          height: ceil(contentSize.height)
        )
        guard controller.view.frame.size != measuredSize else {
          return
        }
        controller.view.frame.size = measuredSize
      }
    }

    return StatusMenuContentConfiguration(
      viewController: controller,
      contentSize: { [weak controller] in
        guard let controller else {
          return NSSize(width: contentWidth, height: 1)
        }
        let fittingSize = controller.sizeThatFits(
          in: CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
        )
        return NSSize(
          width: contentWidth,
          height: max(1, fittingSize.height)
        )
      }
    )
  }

  private func makeFixedHostingController<Content: View>(
    rootView: Content,
    contentSize: NSSize
  ) -> NSHostingController<Content> {
    let controller = NSHostingController(rootView: rootView)
    controller.sizingOptions = []
    controller.preferredContentSize = contentSize
    return controller
  }

  private var routingStatusPresentation: RoutingStatusPresentation {
    RoutingStatusPresentation(
      activeProxyLeaves: monitor.activeProxyLeaves,
      activeRuleTypes: monitor.activeRuleTypes,
      runtimeConfiguration: monitor.runtimeConfiguration
    )
  }

  private var quotaTrendSummary: () -> String {
    {
      let profileCount = profileQuotaController.snapshot.profiles.count
      if profileCount > 0 {
        return "\(profileCount) 个 Profile"
      }
      return quotaController.snapshot.latestQuota == nil ? "暂无数据" : "轻量追踪"
    }
  }

  private var trafficTaskSummary: () -> String {
    {
      TrafficStatisticsPresentation.activeIntervalSummary(
        from: statisticsController.snapshot.intervals
      )
    }
  }

  private var trafficTaskBadge: () -> NSMenuItemBadge? {
    {
      NSMenuItemBadge(
        count: TrafficStatisticsPresentation.activeIntervalCount(
          from: statisticsController.snapshot.intervals
        )
      )
    }
  }

  private var trafficStatisticsMonitoringAvailable: () -> Bool {
    {
      switch monitor.connectionState {
      case .connected, .stale, .reconnecting:
        true
      case .disconnected, .connecting, .authenticationFailed, .unsupported:
        false
      }
    }
  }
}

@MainActor
private final class StatusMenuNaturalHeightHostingController<Content: View>:
  NSHostingController<Content>
{
  var contentSizeDidChange: ((NSSize) -> Void)?

  override init(rootView: Content) {
    super.init(rootView: rootView)
  }

  override var preferredContentSize: NSSize {
    didSet {
      guard preferredContentSize != oldValue else {
        return
      }
      contentSizeDidChange?(preferredContentSize)
    }
  }

  required init?(coder: NSCoder) {
    fatalError("不支持通过 coder 创建状态菜单内容")
  }
}
